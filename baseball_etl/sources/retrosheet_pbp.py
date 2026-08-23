"""dlt source for Retrosheet play-by-play event data.

Retrosheet (https://www.retrosheet.org) publishes one zip archive per season
under `events/{year}eve.zip`, containing a `.EVN`/`.EVA` event file per team
(National/American league home team) in a line-oriented record format:

- id                    starts a new game, e.g. `id,ATL201904010`
- version               format version, ignored
- info,key,value        game metadata (site, date, teams, umpires, ...)
- start,id,"name",h,o,p player in the starting lineup
- play,inn,h,id,cnt,pit,event  a plate appearance / play event
- sub,id,"name",h,o,p   a substitution
- com,"text"            a comment
- data,er,id,n          earned runs charged to a pitcher

This module parses those files directly (no dependency on the Chadwick
`cwevent` tool) and fans the records out into separate tables via
`dlt.mark.with_table_name`/`with_hints`.
"""

import csv
import io
import zipfile
from typing import Iterable, Iterator, Sequence

import dlt
import requests

EVENTS_BASE_URL = "https://www.retrosheet.org/events"


def _event_zip_url(year: int) -> str:
    return f"{EVENTS_BASE_URL}/{year}eve.zip"


def _download_zip(year: int) -> zipfile.ZipFile:
    url = _event_zip_url(year)
    response = requests.get(url, timeout=120)
    response.raise_for_status()
    return zipfile.ZipFile(io.BytesIO(response.content))


def _event_filenames(zf: zipfile.ZipFile) -> Iterator[str]:
    for name in zf.namelist():
        if name.upper().endswith((".EVN", ".EVA")):
            yield name


def _iter_rows(zf: zipfile.ZipFile, filename: str) -> Iterator[list[str]]:
    with zf.open(filename) as f:
        text = f.read().decode("latin-1")
    yield from csv.reader(io.StringIO(text))


def _parse_event_file(rows: Iterable[list[str]], year: int) -> Iterator[tuple[str, dict]]:
    game_id = None
    game_info: dict = {}
    row_seq = 0
    play_seq = 0

    def flush_game():
        if game_id is not None:
            yield "games", {"game_id": game_id, "year": year, **game_info}

    for row in rows:
        if not row:
            continue
        rtype = row[0]

        if rtype == "id":
            yield from flush_game()
            game_id = row[1]
            game_info = {}
            row_seq = 0
            play_seq = 0
        elif rtype == "version":
            continue
        elif rtype == "info":
            if len(row) >= 3:
                game_info[row[1]] = row[2]
        elif rtype in ("start", "sub"):
            if len(row) >= 6:
                row_seq += 1
                table = "starters" if rtype == "start" else "substitutions"
                yield table, {
                    "game_id": game_id,
                    "year": year,
                    "row_seq": row_seq,
                    "player_id": row[1],
                    "player_name": row[2],
                    "home": bool(int(row[3])),
                    "batting_order": int(row[4]),
                    "fielding_position": int(row[5]),
                }
        elif rtype == "play":
            if len(row) >= 7:
                row_seq += 1
                play_seq += 1
                yield "plays", {
                    "game_id": game_id,
                    "year": year,
                    "play_seq": play_seq,
                    "inning": int(row[1]),
                    "home": bool(int(row[2])),
                    "player_id": row[3],
                    "count": row[4],
                    "pitches": row[5],
                    "event": row[6],
                }
        elif rtype == "com":
            row_seq += 1
            yield "comments", {
                "game_id": game_id,
                "year": year,
                "row_seq": row_seq,
                "comment": row[1] if len(row) > 1 else "",
            }
        elif rtype == "data":
            if len(row) >= 4 and row[1] == "er":
                row_seq += 1
                yield "earned_runs", {
                    "game_id": game_id,
                    "year": year,
                    "row_seq": row_seq,
                    "pitcher_id": row[2],
                    "earned_runs": int(row[3]),
                }

    yield from flush_game()


_TABLE_HINTS = {
    table: dlt.mark.make_hints(table_name=table, write_disposition="merge", primary_key=key)
    for table, key in {
        "games": "game_id",
        "plays": ("game_id", "play_seq"),
        "starters": ("game_id", "row_seq"),
        "substitutions": ("game_id", "row_seq"),
        "comments": ("game_id", "row_seq"),
        "earned_runs": ("game_id", "row_seq"),
    }.items()
}


def _parse_year(year: int) -> Iterator[tuple[str, dict]]:
    zf = _download_zip(year)
    try:
        for filename in _event_filenames(zf):
            yield from _parse_event_file(_iter_rows(zf, filename), year)
    finally:
        zf.close()


def _years_from_range(start_year: int, end_year: int | None) -> list[int]:
    return list(range(start_year, (end_year or start_year) + 1))


@dlt.resource(name="retrosheet_pbp")
def retrosheet_pbp(years: Sequence[int]) -> Iterator:
    for year in years:
        for table, row in _parse_year(year):
            yield dlt.mark.with_hints(row, _TABLE_HINTS[table])


@dlt.source(name="retrosheet_pbp")
def retrosheet_pbp_source(start_year: int, end_year: int | None = None):
    """Retrosheet play-by-play data for a single year or an inclusive year range.

    Args:
        start_year: first (or only) season to load, e.g. 2019.
        end_year: last season to load, inclusive. Defaults to `start_year`.
    """
    years = _years_from_range(start_year, end_year)
    return [retrosheet_pbp(years)]
