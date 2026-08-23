"""Entry points for loading source data into Postgres."""

import os
from typing import Iterable

import dlt
from dotenv import load_dotenv

from baseball_etl.sources.chadwick_register import chadwick_register
from baseball_etl.sources.retrosheet_playbyplay import retrosheet_playbyplay

load_dotenv()


def _pipeline(pipeline_name: str) -> dlt.Pipeline:
    return dlt.pipeline(
        pipeline_name=pipeline_name,
        destination=dlt.destinations.postgres(credentials=os.environ["DATABASE_URL"]),
        dataset_name="raw",
    )


def run() -> None:
    run_chadwick_register()


def run_chadwick_register() -> None:
    pipeline = _pipeline("chadwick_register")
    load_info = pipeline.run(chadwick_register())
    print(load_info)


def run_retrosheet_playbyplay(years: Iterable[int]) -> None:
    pipeline = _pipeline("retrosheet_playbyplay")
    load_info = pipeline.run(retrosheet_playbyplay(years))
    print(load_info)
