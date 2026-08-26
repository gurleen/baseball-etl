"""dlt source for Statcast pitch-tracking and batted-ball data from Baseball
Savant's per-game "gamefeed" endpoint (the JSON API behind Savant's live
Gameday scoreboard):

    https://baseballsavant.mlb.com/gf?game_pk={game_pk}

This is undocumented and unauthenticated, but carries more tracking detail
per pitch than Savant's public CSV search export
(https://baseballsavant.mlb.com/statcast_search/csv) — e.g. ABS
challenge-system fields, break angle in multiple units/directions, and
plate-crossing time — which is why it's used here instead of the CSV.

The response holds pitches for the two halves of the game in separate
`team_home`/`team_away` arrays (which array a pitch lands in depends on
which team is on defense, not a true home/away split), each entry tagged
`type: "pitch"` for a real tracked pitch or `type: "no_pitch"` for an empty
ABS-challenge placeholder row with no tracking data. Batted-ball outcome
data (exit velocity, launch angle, hit location) isn't on the pitch rows at
all — it's in a separate `exit_velocity` array, one entry per ball in play,
sharing the same `play_id` as its pitch. That split is preserved here as two
tables (`statcast_pitches`/`statcast_batted_balls`) routed from a single
resource so each game's feed is only fetched once.

Games for a season (or date range within one) are discovered via the
schedule endpoint, the same way `mlb_playbyplay.py` and `mlb_games.py` find
game_pks to fetch.

Per-game feed fetches are I/O-bound (one HTTP round trip each, ~2400 games
for a full season) so they're done concurrently with a thread pool rather
than one at a time.
"""

import datetime as dt
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Iterable, Iterator, Optional

import dlt
import requests
from loguru import logger

SCHEDULE_URL = "https://statsapi.mlb.com/api/v1/schedule"
GAME_FEED_URL = "https://baseballsavant.mlb.com/gf"
MAX_WORKERS = 8

_session = requests.Session()


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


def _fetch_game_feed(game_pk: int) -> dict:
    response = _session.get(GAME_FEED_URL, params={"game_pk": game_pk}, timeout=60)
    response.raise_for_status()
    return response.json()


def fetch_game_pks(
    season: Optional[int] = None,
    game_types: str = "R",
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
) -> list[int]:
    """Resolve the game_pks for a season/date range via the schedule endpoint,
    without fetching any per-game feeds. Lets callers split a season's worth
    of games into smaller batches before running the pipeline."""
    resolved_season = season or _current_season()
    return list(_fetch_game_pks(resolved_season, game_types, start_date, end_date))


@dlt.source(name="statcast")
def statcast(
    season: Optional[int] = None,
    game_types: str = "R",
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    game_pks: Optional[Iterable[int]] = None,
):
    """Statcast pitch-tracking and batted-ball data for a season, defaulting
    to the current one.

    `game_types` is MLB's comma-separated game type code ("R" for regular
    season, "F,D,L,W" for postseason rounds, etc). `start_date`/`end_date`
    (YYYY-MM-DD) narrow the schedule lookup, useful for smaller incremental
    runs during the current season rather than refetching every game.
    `game_pks`, if given, is fetched directly instead of resolving the
    schedule, e.g. for running a season in memory-bounded batches.
    """
    resolved_season = season or _current_season()

    @dlt.resource(
        name="statcast_pitches", write_disposition="merge", primary_key="play_id"
    )
    def statcast_pitches() -> Iterator[dict]:
        if game_pks is not None:
            resolved_game_pks = list(game_pks)
        else:
            resolved_game_pks = list(
                _fetch_game_pks(resolved_season, game_types, start_date, end_date)
            )
        games_processed = 0
        pitches_yielded = 0
        balls_yielded = 0

        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = {
                executor.submit(_fetch_game_feed, game_pk): game_pk
                for game_pk in resolved_game_pks
            }
            for future in as_completed(futures):
                game_pk = futures[future]
                feed = future.result()

                for pitch in feed.get("team_home", []) + feed.get("team_away", []):
                    if pitch.get("type") != "pitch":
                        continue
                    pitch["game_pk"] = int(game_pk)
                    pitches_yielded += 1
                    yield pitch

                for batted_ball in feed.get("exit_velocity", []):
                    batted_ball["game_pk"] = int(game_pk)
                    balls_yielded += 1
                    yield dlt.mark.with_table_name(batted_ball, "statcast_batted_balls")

                games_processed += 1
                if games_processed % 50 == 0:
                    logger.info(
                        "Progress: {} games processed, {} pitches / {} batted balls yielded so far",
                        games_processed,
                        pitches_yielded,
                        balls_yielded,
                    )
        logger.info(
            "Done: {} games processed, {} pitches / {} batted balls yielded",
            games_processed,
            pitches_yielded,
            balls_yielded,
        )

    return statcast_pitches
