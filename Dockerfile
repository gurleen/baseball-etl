# Ad-hoc runner image for baseball-etl cron jobs (dlt loaders + SQLMesh runs).
#
# Not a long-running service: Coolify spins up a container per scheduled job,
# runs a command, and tears it down. Entrypoint is `uv run`, so a Coolify cron
# job's "command" is just the args you'd normally pass after that, e.g.:
#   main.py mlb-games --game-types R
#   sqlmesh --paths transform run
FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1

# Install deps first (incl. the dev group, since sqlmesh lives there) so this
# layer is cached across code-only changes.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --group dev

COPY . .

ENTRYPOINT ["uv", "run"]
CMD ["main.py", "--help"]
