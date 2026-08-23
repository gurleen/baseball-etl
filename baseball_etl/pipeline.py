"""Entry points for loading baseball data sources into Postgres."""

import os

import dlt
from dotenv import load_dotenv

from baseball_etl.sources.chadwick_register import chadwick_register
from baseball_etl.sources.retrosheet_pbp import retrosheet_pbp_source

load_dotenv()


def _postgres_pipeline(pipeline_name: str) -> dlt.Pipeline:
    return dlt.pipeline(
        pipeline_name=pipeline_name,
        destination=dlt.destinations.postgres(credentials=os.environ["DATABASE_URL"]),
        dataset_name="raw",
    )


def run() -> None:
    """Load the Chadwick Bureau register (kept for backwards compatibility)."""
    run_chadwick_register()


def run_chadwick_register() -> None:
    pipeline = _postgres_pipeline("chadwick_register")
    load_info = pipeline.run(chadwick_register())
    print(load_info)


def run_retrosheet_pbp(start_year: int, end_year: int | None = None) -> None:
    pipeline = _postgres_pipeline("retrosheet_pbp")
    load_info = pipeline.run(retrosheet_pbp_source(start_year, end_year))
    print(load_info)
