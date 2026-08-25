# Prefect worker image for baseball-etl: a persistent Coolify service running
# this image registers the deployments in prefect.yaml, then polls the
# "baseball-etl" work pool and executes the scheduled/manual flows in
# baseball_etl/flows.py (dlt loaders + SQLMesh runs). Needs PREFECT_API_URL
# and DATABASE_URL set as env vars.
FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1 \
    PREFECT_LOGGING_EXTRA_LOGGERS=baseball_etl

# Install deps first (incl. the dev group, since sqlmesh lives there) so this
# layer is cached across code-only changes.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --group dev

COPY . .

RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
