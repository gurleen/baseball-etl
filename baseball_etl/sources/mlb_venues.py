"""dlt source for MLB Stats API's venue reference data (ballparks), one
snapshot per season. The venues endpoint doesn't carry a season field on
each record itself, so it's injected from the API-call context.
"""

import datetime as dt
from typing import Iterable, Iterator, Optional

import dlt
import requests

VENUES_URL = "https://statsapi.mlb.com/api/v1/venues"


def _current_season() -> int:
    return dt.date.today().year


def _fetch_venues(season: int) -> Iterator[dict]:
    response = requests.get(
        VENUES_URL,
        params={
            "sportId": 1,
            "season": season,
            "hydrate": "location,fieldInfo,timezone",
        },
        timeout=60,
    )
    response.raise_for_status()
    for venue in response.json().get("venues", []):
        venue["season"] = season
        yield venue


@dlt.source(name="mlb_venues")
def mlb_venues(seasons: Optional[Iterable[int]] = None):
    resolved_seasons = list(seasons) if seasons is not None else [_current_season()]

    @dlt.resource(name="venues", write_disposition="merge", primary_key=["id", "season"])
    def venues() -> Iterator[dict]:
        for season in resolved_seasons:
            yield from _fetch_venues(season)

    return venues
