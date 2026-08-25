# baseball-etl

## Loading raw data

dlt pipelines fetch source data (Chadwick register, Retrosheet, MLB play-by-play) into the
`raw` schema of the Postgres database at `DATABASE_URL`:

```sh
uv run main.py chadwick-register
uv run main.py retrosheet-playbyplay --years 2019-2023
uv run main.py mlb-playbyplay --season 2026
```

FanGraphs' guts constants (wOBA weights, run values, etc.) can't be scraped —
FanGraphs blocks scrapers — so instead download the CSV from
https://www.fangraphs.com/guts.aspx?type=cn, overwrite
`data/fangraphs_guts.csv`, commit, and either push to `main` (the
`fangraphs-guts` workflow runs automatically on changes to that file) or load
it locally:

```sh
uv run main.py fangraphs-guts
```

FanGraphs' park factors work the same way — download the CSV from
https://www.fangraphs.com/guts.aspx?type=pf, overwrite
`data/fangraphs_park_factors.csv`, commit, and either push to `main` (the
`fangraphs-park-factors` workflow runs automatically on changes to that file)
or load it locally:

```sh
uv run main.py fangraphs-park-factors
```

## Transforming with SQLMesh

The `transform/` directory is a [SQLMesh](https://sqlmesh.readthedocs.io/) project that
builds models on top of the `raw` tables loaded by dlt, using the same `DATABASE_URL`
(see `transform/config.py`).

```sh
uv run sqlmesh --paths transform plan
uv run sqlmesh --paths transform run
```

New raw tables can be scaffolded into staging models with:

```sh
uv run sqlmesh --paths transform init -t dlt --dlt-pipeline <pipeline_name> postgres
```
