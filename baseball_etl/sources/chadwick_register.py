"""dlt source for the Chadwick Bureau Register.

The register (https://github.com/chadwickbureau/register) is a crosswalk of
player/manager/umpire identifiers across MLBAM, Retrosheet, Baseball-Reference,
Fangraphs, etc. Data is published as CSVs under `data/` on the `master` branch:

- people-{0-9,a-f}.csv  sharded by the first hex digit of `key_person`
- names.csv, links.csv, countries.csv  small reference tables
"""

import csv
from io import StringIO
from typing import Iterator

import dlt
import requests

RAW_BASE_URL = (
    "https://raw.githubusercontent.com/chadwickbureau/register/master/data"
)
PEOPLE_SHARDS = "0123456789abcdef"


def _fetch_csv_rows(filename: str) -> Iterator[dict]:
    url = f"{RAW_BASE_URL}/{filename}"
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    yield from csv.DictReader(StringIO(response.text))


@dlt.resource(name="people", write_disposition="merge", primary_key="key_person")
def people() -> Iterator[dict]:
    for shard in PEOPLE_SHARDS:
        yield from _fetch_csv_rows(f"people-{shard}.csv")


@dlt.resource(name="names", write_disposition="replace")
def names() -> Iterator[dict]:
    yield from _fetch_csv_rows("names.csv")


@dlt.resource(name="links", write_disposition="replace")
def links() -> Iterator[dict]:
    yield from _fetch_csv_rows("links.csv")


@dlt.resource(name="countries", write_disposition="replace")
def countries() -> Iterator[dict]:
    yield from _fetch_csv_rows("countries.csv")


@dlt.source(name="chadwick_register")
def chadwick_register():
    return [people(), names(), links(), countries()]
