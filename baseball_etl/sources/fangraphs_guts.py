"""dlt source for FanGraphs' "guts" constants (wOBA weights, run values,
runs-per-win, etc.) by season.

FanGraphs blocks scrapers, so this data can't be fetched from an API like
the other sources — instead it's a CSV manually downloaded from
https://www.fangraphs.com/guts.aspx?type=cn and committed to the repo at
`data/fangraphs_guts.csv`. To refresh: download the updated CSV from that
page, overwrite `data/fangraphs_guts.csv`, commit, and re-run this loader.
"""

import csv
from pathlib import Path
from typing import Iterator

import dlt

DEFAULT_PATH = Path(__file__).parent.parent.parent / "data" / "fangraphs_guts.csv"


def _fetch_rows(path: Path) -> Iterator[dict]:
    with path.open(encoding="utf-8-sig") as f:
        yield from csv.DictReader(f)


@dlt.source(name="fangraphs_guts")
def fangraphs_guts(path: Path = DEFAULT_PATH):
    @dlt.resource(name="fangraphs_guts", write_disposition="merge", primary_key="season")
    def guts() -> Iterator[dict]:
        yield from _fetch_rows(path)

    return guts
