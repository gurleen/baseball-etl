"""dlt source for MLB Stats API's sports reference list (MLB, AAA, AA, etc.).

Genuinely static reference data - no season dimension, so this is a
one-shot `replace` load rather than `merge`.
"""

from typing import Iterator

import dlt
import requests

SPORTS_URL = "https://statsapi.mlb.com/api/v1/sports"


def _fetch_sports() -> Iterator[dict]:
    response = requests.get(SPORTS_URL, timeout=60)
    response.raise_for_status()
    yield from response.json().get("sports", [])


@dlt.source(name="mlb_sports")
def mlb_sports():
    @dlt.resource(name="sports", write_disposition="replace", primary_key="id")
    def sports() -> Iterator[dict]:
        yield from _fetch_sports()

    return sports
