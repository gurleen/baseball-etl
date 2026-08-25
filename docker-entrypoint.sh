#!/bin/sh
# Re-register deployments from prefect.yaml on every start (idempotent
# upsert), so a code push + Coolify redeploy picks up new/changed flows
# without a manual `prefect deploy` from a laptop.
set -e
uv run prefect deploy --all
exec uv run prefect worker start --pool baseball-etl
