"""dlt source for Retrosheet's pre-parsed play-by-play data.

Retrosheet publishes fully parsed play-by-play data (one row per game
event, ~177 columns covering counts, baserunners, fielding, etc.) as a
zipped CSV per season:

    https://www.retrosheet.org/downloads/plays/{year}plays.zip

This uses that pre-parsed data directly rather than parsing the raw
.EVN/.EVA event files with a tool like Chadwick's cwevent.
"""

import csv
import io
import zipfile
from typing import Iterable, Iterator

import dlt
import requests

PLAYS_URL = "https://www.retrosheet.org/downloads/plays/{year}plays.zip"


def _fetch_year_rows(year: int) -> Iterator[dict]:
    response = requests.get(PLAYS_URL.format(year=year), timeout=120)
    response.raise_for_status()
    with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
        (filename,) = archive.namelist()
        with archive.open(filename) as raw:
            reader = csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8"))
            for row in reader:
                row["season"] = year
                yield row


@dlt.source(name="retrosheet_playbyplay")
def retrosheet_playbyplay(years: Iterable[int]):
    @dlt.resource(name="plays", write_disposition="merge", primary_key=["gid", "pn"])
    def plays() -> Iterator[dict]:
        for year in years:
            yield from _fetch_year_rows(year)

    return plays
