"""dlt source for MLB team reference data (name, venue, division, etc.)
from the MLB Stats API.

Loads one snapshot per requested season, since team attributes
(name/venue/division) change across seasons — e.g. team id 133 was the
Philadelphia Athletics in 1901 and is the Athletics (Sacramento) in 2025.
"""

import datetime as dt
from typing import Iterable, Iterator, Optional

import dlt
import requests

TEAMS_URL = "https://statsapi.mlb.com/api/v1/teams"


def _current_season() -> int:
    return dt.date.today().year


def _fetch_teams(season: int) -> Iterator[dict]:
    response = requests.get(TEAMS_URL, params={"sportId": 1, "season": season}, timeout=60)
    response.raise_for_status()
    yield from response.json().get("teams", [])


@dlt.source(name="mlb_teams")
def mlb_teams(seasons: Optional[Iterable[int]] = None):
    resolved_seasons = list(seasons) if seasons is not None else [_current_season()]

    @dlt.resource(name="teams", write_disposition="merge", primary_key=["id", "season"])
    def teams() -> Iterator[dict]:
        for season in resolved_seasons:
            yield from _fetch_teams(season)

    return teams
