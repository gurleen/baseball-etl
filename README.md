# baseball-etl

## Loading raw data

dlt pipelines fetch source data (Chadwick register, Retrosheet, MLB play-by-play) into the
`raw` schema of the Postgres database at `DATABASE_URL`:

```sh
uv run main.py chadwick-register
uv run main.py retrosheet-playbyplay --years 2019-2023
uv run main.py mlb-playbyplay --season 2026
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
