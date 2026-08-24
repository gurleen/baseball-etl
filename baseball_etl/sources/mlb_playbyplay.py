"""dlt source for current-season MLB play-by-play data from the MLB Stats
API's live game feed (the "GUMBO" format).

MLB exposes a per-game play-by-play feed:

    https://statsapi.mlb.com/api/v1.1/game/{game_pk}/feed/live

`liveData.plays.allPlays` is a list of plays (one per plate appearance),
each carrying nested pitch-by-pitch `playEvents`, baserunner movement, and
matchup detail. dlt flattens/normalizes this nested structure into child
tables automatically.

Games for a season (or date range within one) are discovered via the
schedule endpoint:

    https://statsapi.mlb.com/api/v1/schedule

This loads into its own `mlb_plays` table so it doesn't collide with the
(differently-shaped) Retrosheet `plays` table, even though both land in the
same `raw` schema.
"""

import datetime as dt
from typing import Iterator, Optional

import dlt
import requests
from loguru import logger

SCHEDULE_URL = "https://statsapi.mlb.com/api/v1/schedule"
LIVE_FEED_URL = "https://statsapi.mlb.com/api/v1.1/game/{game_pk}/feed/live"


def _current_season() -> int:
    return dt.date.today().year


def _fetch_game_pks(
    season: int,
    game_types: str,
    start_date: Optional[str],
    end_date: Optional[str],
) -> Iterator[int]:
    params = {"sportId": 1, "season": season, "gameType": game_types}
    # The schedule endpoint 400s if startDate/endDate is given without the
    # other, so fill in the missing bound from the season's calendar year.
    if start_date or end_date:
        params["startDate"] = start_date or f"{season}-01-01"
        params["endDate"] = end_date or f"{season}-12-31"
    logger.info(
        "Fetching schedule: season={} game_types={} start_date={} end_date={}",
        season,
        game_types,
        params.get("startDate", "(unbounded)"),
        params.get("endDate", "(unbounded)"),
    )
    response = requests.get(SCHEDULE_URL, params=params, timeout=60)
    response.raise_for_status()
    game_pks = [
        game["gamePk"]
        for date in response.json().get("dates", [])
        for game in date.get("games", [])
    ]
    logger.info("Schedule returned {} games", len(game_pks))
    yield from game_pks


def _fetch_game_plays(game_pk: int) -> Iterator[dict]:
    response = requests.get(LIVE_FEED_URL.format(game_pk=game_pk), timeout=120)
    response.raise_for_status()
    payload = response.json()
    plays = payload.get("liveData", {}).get("plays", {}).get("allPlays", [])
    logger.debug("game_pk={} yielded {} plays", game_pk, len(plays))
    for play in plays:
        play["game_pk"] = game_pk
        play["at_bat_index"] = play.get("about", {}).get("atBatIndex")
        yield play


@dlt.source(name="mlb_playbyplay")
def mlb_playbyplay(
    season: Optional[int] = None,
    game_types: str = "R",
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
):
    """Play-by-play for a season, defaulting to the current one.

    `game_types` is MLB's comma-separated game type code ("R" for regular
    season, "F,D,L,W" for postseason rounds, etc). `start_date`/`end_date`
    (YYYY-MM-DD) narrow the schedule lookup, useful for smaller incremental
    runs during the current season rather than refetching every game.
    """
    resolved_season = season or _current_season()

    @dlt.resource(
        name="mlb_plays", write_disposition="merge", primary_key=["game_pk", "at_bat_index"]
    )
    def mlb_plays() -> Iterator[dict]:
        games_processed = 0
        plays_yielded = 0
        for game_pk in _fetch_game_pks(resolved_season, game_types, start_date, end_date):
            for play in _fetch_game_plays(game_pk):
                plays_yielded += 1
                yield play
            games_processed += 1
            if games_processed % 50 == 0:
                logger.info(
                    "Progress: {} games processed, {} plays yielded so far",
                    games_processed,
                    plays_yielded,
                )
        logger.info(
            "Done: {} games processed, {} plays yielded", games_processed, plays_yielded
        )

    return mlb_plays
