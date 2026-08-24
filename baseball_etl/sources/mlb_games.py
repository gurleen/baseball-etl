"""dlt source for the MLB schedule endpoint (team, score, venue, and
status per game) — the game-level counterpart to `mlb_playbyplay`'s
per-play data, which carries no team/score/venue info of its own.

    https://statsapi.mlb.com/api/v1/schedule

Games for a season (or date range within one) are discovered the same
way `mlb_playbyplay` finds game_pks to fetch play-by-play for.
"""

import datetime as dt
from typing import Iterator, Optional

import dlt
import requests

SCHEDULE_URL = "https://statsapi.mlb.com/api/v1/schedule"


def _current_season() -> int:
    return dt.date.today().year


def _fetch_games(
    season: int,
    game_types: str,
    start_date: Optional[str],
    end_date: Optional[str],
) -> Iterator[dict]:
    params = {"sportId": 1, "season": season, "gameType": game_types}
    if start_date or end_date:
        params["startDate"] = start_date or f"{season}-01-01"
        params["endDate"] = end_date or f"{season}-12-31"
    response = requests.get(SCHEDULE_URL, params=params, timeout=60)
    response.raise_for_status()
    for date in response.json().get("dates", []):
        for game in date.get("games", []):
            yield game


@dlt.source(name="mlb_games")
def mlb_games(
    season: Optional[int] = None,
    game_types: str = "R",
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
):
    resolved_season = season or _current_season()

    @dlt.resource(name="games", write_disposition="merge", primary_key="game_pk")
    def games() -> Iterator[dict]:
        yield from _fetch_games(resolved_season, game_types, start_date, end_date)

    return games
