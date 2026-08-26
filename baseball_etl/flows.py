"""Prefect flows that replace the GitHub Actions workflows in
`.github/workflows/`. One flow per workflow file; tasks just call the
existing `run_*()` functions in `pipeline.py` — no pipeline logic here."""

import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

from prefect import flow, get_run_logger, task

from baseball_etl import logging_bridge
from baseball_etl.notifications import notify_failure
from baseball_etl.pipeline import (
    run_chadwick_register,
    run_fangraphs_guts,
    run_fangraphs_park_factors,
    run_mlb_divisions,
    run_mlb_games,
    run_mlb_leagues,
    run_mlb_playbyplay,
    run_mlb_sports,
    run_mlb_teams,
    run_mlb_venues,
    run_retrosheet_playbyplay,
    run_statcast,
)
from baseball_etl.sources.statcast import fetch_game_pks

logging_bridge.install()

# Fetching a full season's worth of games (~2400) in one dlt extraction run
# holds every game's feed data in memory at once, which has crashed the
# backfill on constrained workers. Splitting into batches this size and
# running the pipeline separately per batch keeps peak memory bounded and
# lets earlier batches' data get garbage-collected before the next one starts.
STATCAST_BATCH_SIZE = 300


def _chunk(items: list[int], size: int) -> list[list[int]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def _parse_seasons(spec: str | None) -> list[int] | None:
    """Parse a year or comma-separated list of years/ranges, e.g. "2021",
    "2019-2023", or "2015-2017,2020-2024". Mirrors main.py's parse_years."""
    if not spec:
        return None
    years: list[int] = []
    for chunk in spec.split(","):
        chunk = chunk.strip()
        if "-" in chunk:
            start, end = chunk.split("-", 1)
            years.extend(range(int(start), int(end) + 1))
        else:
            years.append(int(chunk))
    return years


def _days_ago(days: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_games(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    run_mlb_games(season=season, game_types=game_types, start_date=start_date, end_date=end_date)


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_playbyplay(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    run_mlb_playbyplay(season=season, game_types=game_types, start_date=start_date, end_date=end_date)


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_statcast(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    run_statcast(season=season, game_types=game_types, start_date=start_date, end_date=end_date)


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_statcast_batch(game_pks: list[int]) -> None:
    run_statcast(game_pks=game_pks)


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_teams(seasons: str | None = None) -> None:
    run_mlb_teams(_parse_seasons(seasons))


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_sports() -> None:
    run_mlb_sports()


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_leagues(seasons: str | None = None) -> None:
    run_mlb_leagues(_parse_seasons(seasons))


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_divisions(seasons: str | None = None) -> None:
    run_mlb_divisions(_parse_seasons(seasons))


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_mlb_venues(seasons: str | None = None) -> None:
    run_mlb_venues(_parse_seasons(seasons))


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_chadwick_register() -> None:
    run_chadwick_register()


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_fangraphs_guts(path: Path | None = None) -> None:
    if path is not None:
        run_fangraphs_guts(path)
    else:
        run_fangraphs_guts()


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_fangraphs_park_factors(path: Path | None = None) -> None:
    if path is not None:
        run_fangraphs_park_factors(path)
    else:
        run_fangraphs_park_factors()


@task(retries=2, retry_delay_seconds=60, log_prints=True)
def load_retrosheet_playbyplay(years: str) -> None:
    run_retrosheet_playbyplay(_parse_seasons(years))


def _run_and_log(args: list[str]) -> None:
    run_logger = get_run_logger()
    result = subprocess.run(args, capture_output=True, text=True)
    if result.stdout:
        run_logger.info(result.stdout)
    if result.stderr:
        run_logger.info(result.stderr)
    result.check_returncode()


@task
def sqlmesh_run() -> None:
    _run_and_log(["uv", "run", "sqlmesh", "--paths", "transform", "run"])


@task
def sqlmesh_plan_auto_apply(force: bool = False) -> None:
    args = ["uv", "run", "sqlmesh", "--paths", "transform", "plan", "--auto-apply"]
    if force:
        args += ["--restate-model", "*.*"]
    _run_and_log(args)


@flow(name="mlb-games", on_failure=[notify_failure])
def mlb_games_flow(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    load_mlb_games(season=season, game_types=game_types, start_date=start_date, end_date=end_date)


@flow(name="mlb-playbyplay", on_failure=[notify_failure])
def mlb_playbyplay_flow(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    if start_date is None:
        start_date = _days_ago(7)
    load_mlb_playbyplay(season=season, game_types=game_types, start_date=start_date, end_date=end_date)
    sqlmesh_run()


@flow(name="mlb-playbyplay-backfill", on_failure=[notify_failure])
def mlb_playbyplay_backfill_flow(
    season: int | None = None,
    game_types: str = "R",
) -> None:
    end_date = _days_ago(1)
    load_mlb_playbyplay(season=season, game_types=game_types, end_date=end_date)
    sqlmesh_run()


@flow(name="statcast", on_failure=[notify_failure])
def statcast_flow(
    season: int | None = None,
    game_types: str = "R",
    start_date: str | None = None,
    end_date: str | None = None,
) -> None:
    if start_date is None:
        start_date = _days_ago(7)
    load_statcast(season=season, game_types=game_types, start_date=start_date, end_date=end_date)
    sqlmesh_run()


@flow(name="statcast-backfill", on_failure=[notify_failure])
def statcast_backfill_flow(
    season: int | None = None,
    game_types: str = "R",
) -> None:
    end_date = _days_ago(1)
    game_pks = fetch_game_pks(season=season, game_types=game_types, end_date=end_date)
    for batch in _chunk(game_pks, STATCAST_BATCH_SIZE):
        load_statcast_batch(batch)
    sqlmesh_run()


@flow(name="mlb-teams", on_failure=[notify_failure])
def mlb_teams_flow(seasons: str | None = None) -> None:
    load_mlb_teams(seasons=seasons)


@flow(name="mlb-sports", on_failure=[notify_failure])
def mlb_sports_flow() -> None:
    load_mlb_sports()


@flow(name="mlb-leagues", on_failure=[notify_failure])
def mlb_leagues_flow(seasons: str | None = None) -> None:
    load_mlb_leagues(seasons=seasons)


@flow(name="mlb-divisions", on_failure=[notify_failure])
def mlb_divisions_flow(seasons: str | None = None) -> None:
    load_mlb_divisions(seasons=seasons)


@flow(name="mlb-venues", on_failure=[notify_failure])
def mlb_venues_flow(seasons: str | None = None) -> None:
    load_mlb_venues(seasons=seasons)


@flow(name="chadwick-register", on_failure=[notify_failure])
def chadwick_register_flow() -> None:
    load_chadwick_register()


@flow(name="fangraphs-guts", on_failure=[notify_failure])
def fangraphs_guts_flow(path: str | None = None) -> None:
    load_fangraphs_guts(Path(path) if path else None)


@flow(name="fangraphs-park-factors", on_failure=[notify_failure])
def fangraphs_park_factors_flow(path: str | None = None) -> None:
    load_fangraphs_park_factors(Path(path) if path else None)


@flow(name="retrosheet-playbyplay", on_failure=[notify_failure])
def retrosheet_playbyplay_flow(years: str) -> None:
    load_retrosheet_playbyplay(years)


@flow(name="sqlmesh-plan", on_failure=[notify_failure])
def sqlmesh_plan_flow(force: bool = False) -> None:
    sqlmesh_plan_auto_apply(force=force)
