"""dlt source for MLB Stats API's league reference data (American League,
National League, etc.), one snapshot per season.
"""

import datetime as dt
from typing import Iterable, Iterator, Optional

import dlt
import requests

LEAGUES_URL = "https://statsapi.mlb.com/api/v1/league"


def _current_season() -> int:
    return dt.date.today().year


def _fetch_leagues(season: int) -> Iterator[dict]:
    response = requests.get(LEAGUES_URL, params={"sportId": 1, "season": season}, timeout=60)
    response.raise_for_status()
    yield from response.json().get("leagues", [])


@dlt.source(name="mlb_leagues")
def mlb_leagues(seasons: Optional[Iterable[int]] = None):
    resolved_seasons = list(seasons) if seasons is not None else [_current_season()]

    @dlt.resource(name="leagues", write_disposition="merge", primary_key=["id", "season"])
    def leagues() -> Iterator[dict]:
        for season in resolved_seasons:
            yield from _fetch_leagues(season)

    return leagues
