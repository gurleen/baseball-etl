#!/bin/sh
# Re-register deployments from prefect.yaml on every start (idempotent
# upsert), so a code push + Coolify redeploy picks up new/changed flows
# without a manual `prefect deploy` from a laptop.
set -e
uv run prefect deploy --all

# Same idempotent-upsert idea for the Pushover notification block: re-save it
# on every start so a token/user rotation just needs new env vars + a
# redeploy, not a manual `python -m baseball_etl.notifications` from a
# laptop. Skipped if the env vars aren't set (e.g. Pushover not configured).
if [ -n "$PUSHOVER_TOKEN" ] && [ -n "$PUSHOVER_USER" ]; then
    uv run python -m baseball_etl.notifications
else
    echo "PUSHOVER_TOKEN/PUSHOVER_USER not set, skipping Pushover block registration."
fi

exec uv run prefect worker start --pool baseball-etl
