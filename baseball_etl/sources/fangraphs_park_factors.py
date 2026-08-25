"""dlt source for FanGraphs' park factors by team/season.

FanGraphs blocks scrapers, so this data can't be fetched from an API like
the other sources — instead it's a CSV manually downloaded from
https://www.fangraphs.com/guts.aspx?type=pf&season=2025&teamid=0&
and committed to the repo at `data/fangraphs_park_factors.csv`. To refresh:
download the updated CSV from that page, overwrite
`data/fangraphs_park_factors.csv`, commit, and re-run this loader.
"""

import csv
from pathlib import Path
from typing import Iterator

import dlt

DEFAULT_PATH = Path(__file__).parent.parent.parent / "data" / "fangraphs_park_factors.csv"


def _fetch_rows(path: Path) -> Iterator[dict]:
    with path.open(encoding="utf-8-sig") as f:
        yield from csv.DictReader(f)


@dlt.source(name="fangraphs_park_factors")
def fangraphs_park_factors(path: Path = DEFAULT_PATH):
    @dlt.resource(
        name="fangraphs_park_factors",
        write_disposition="merge",
        primary_key=["season", "team"],
    )
    def park_factors() -> Iterator[dict]:
        yield from _fetch_rows(path)

    return park_factors
