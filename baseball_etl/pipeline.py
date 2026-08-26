"""Entry points for loading source data into Postgres."""

import os
import time
from pathlib import Path
from typing import Iterable

import dlt
from dotenv import load_dotenv
from loguru import logger

from baseball_etl.sources.chadwick_register import chadwick_register
from baseball_etl.sources.fangraphs_guts import DEFAULT_PATH as FANGRAPHS_GUTS_DEFAULT_PATH
from baseball_etl.sources.fangraphs_guts import fangraphs_guts
from baseball_etl.sources.fangraphs_park_factors import (
    DEFAULT_PATH as FANGRAPHS_PARK_FACTORS_DEFAULT_PATH,
)
from baseball_etl.sources.fangraphs_park_factors import fangraphs_park_factors
from baseball_etl.sources.mlb_divisions import mlb_divisions
from baseball_etl.sources.mlb_games import mlb_games
from baseball_etl.sources.mlb_leagues import mlb_leagues
from baseball_etl.sources.mlb_playbyplay import mlb_playbyplay
from baseball_etl.sources.mlb_sports import mlb_sports
from baseball_etl.sources.mlb_teams import mlb_teams
from baseball_etl.sources.mlb_venues import mlb_venues
from baseball_etl.sources.retrosheet_playbyplay import retrosheet_playbyplay
from baseball_etl.sources.statcast import statcast

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


def run_fangraphs_guts(path: Path = FANGRAPHS_GUTS_DEFAULT_PATH) -> None:
    pipeline = _pipeline("fangraphs_guts")
    load_info = pipeline.run(fangraphs_guts(path))
    print(load_info)


def run_fangraphs_park_factors(path: Path = FANGRAPHS_PARK_FACTORS_DEFAULT_PATH) -> None:
    pipeline = _pipeline("fangraphs_park_factors")
    load_info = pipeline.run(fangraphs_park_factors(path))
    print(load_info)


def run_retrosheet_playbyplay(years: Iterable[int]) -> None:
    pipeline = _pipeline("retrosheet_playbyplay")
    load_info = pipeline.run(retrosheet_playbyplay(years))
    print(load_info)


def run_mlb_games(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    pipeline = _pipeline("mlb_games")
    load_info = pipeline.run(
        mlb_games(
            season=season,
            game_types=game_types,
            start_date=start_date,
            end_date=end_date,
        )
    )
    print(load_info)


def run_mlb_teams(seasons: Iterable[int] | None = None) -> None:
    pipeline = _pipeline("mlb_teams")
    load_info = pipeline.run(mlb_teams(seasons=seasons))
    print(load_info)


def run_mlb_sports() -> None:
    pipeline = _pipeline("mlb_sports")
    load_info = pipeline.run(mlb_sports())
    print(load_info)


def run_mlb_leagues(seasons: Iterable[int] | None = None) -> None:
    pipeline = _pipeline("mlb_leagues")
    load_info = pipeline.run(mlb_leagues(seasons=seasons))
    print(load_info)


def run_mlb_divisions(seasons: Iterable[int] | None = None) -> None:
    pipeline = _pipeline("mlb_divisions")
    load_info = pipeline.run(mlb_divisions(seasons=seasons))
    print(load_info)


def run_mlb_venues(seasons: Iterable[int] | None = None) -> None:
    pipeline = _pipeline("mlb_venues")
    load_info = pipeline.run(mlb_venues(seasons=seasons))
    print(load_info)


def run_mlb_playbyplay(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    logger.info(
        "Starting mlb_playbyplay run: season={} game_types={} start_date={} end_date={}",
        season,
        game_types,
        start_date,
        end_date,
    )
    started = time.monotonic()
    pipeline = _pipeline("mlb_playbyplay")
    load_info = pipeline.run(
        mlb_playbyplay(
            season=season,
            game_types=game_types,
            start_date=start_date,
            end_date=end_date,
        )
    )
    elapsed = time.monotonic() - started
    logger.info("mlb_playbyplay run finished in {:.1f}s", elapsed)
    print(load_info)


def run_statcast(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
    game_pks: Iterable[int] | None = None,
) -> None:
    game_pks = list(game_pks) if game_pks is not None else None
    logger.info(
        "Starting statcast run: season={} game_types={} start_date={} end_date={} game_pks={}",
        season,
        game_types,
        start_date,
        end_date,
        f"{len(game_pks)} explicit" if game_pks is not None else None,
    )
    started = time.monotonic()
    pipeline = _pipeline("statcast")
    load_info = pipeline.run(
        statcast(
            season=season,
            game_types=game_types,
            start_date=start_date,
            end_date=end_date,
            game_pks=game_pks,
        )
    )
    elapsed = time.monotonic() - started
    logger.info("statcast run finished in {:.1f}s", elapsed)
    print(load_info)
