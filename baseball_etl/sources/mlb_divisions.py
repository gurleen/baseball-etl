"""dlt source for MLB Stats API's division reference data (AL West, NL
East, etc.), one snapshot per season - the set of divisions has changed
over time (e.g. Central divisions were added in 1994).
"""

import datetime as dt
from typing import Iterable, Iterator, Optional

import dlt
import requests

DIVISIONS_URL = "https://statsapi.mlb.com/api/v1/divisions"


def _current_season() -> int:
    return dt.date.today().year


def _fetch_divisions(season: int) -> Iterator[dict]:
    response = requests.get(DIVISIONS_URL, params={"sportId": 1, "season": season}, timeout=60)
    response.raise_for_status()
    yield from response.json().get("divisions", [])


@dlt.source(name="mlb_divisions")
def mlb_divisions(seasons: Optional[Iterable[int]] = None):
    resolved_seasons = list(seasons) if seasons is not None else [_current_season()]

    @dlt.resource(name="divisions", write_disposition="merge", primary_key=["id", "season"])
    def divisions() -> Iterator[dict]:
        for season in resolved_seasons:
            yield from _fetch_divisions(season)

    return divisions
