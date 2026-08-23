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
    if start_date:
        params["startDate"] = start_date
    if end_date:
        params["endDate"] = end_date
    response = requests.get(SCHEDULE_URL, params=params, timeout=60)
    response.raise_for_status()
    for date in response.json().get("dates", []):
        for game in date.get("games", []):
            yield game["gamePk"]


def _fetch_game_plays(game_pk: int) -> Iterator[dict]:
    response = requests.get(LIVE_FEED_URL.format(game_pk=game_pk), timeout=120)
    response.raise_for_status()
    payload = response.json()
    for play in payload.get("liveData", {}).get("plays", {}).get("allPlays", []):
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
        for game_pk in _fetch_game_pks(resolved_season, game_types, start_date, end_date):
            yield from _fetch_game_plays(game_pk)

    return mlb_plays
