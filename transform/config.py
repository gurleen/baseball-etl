"""SQLMesh project config.

Connects to the same Postgres database the dlt pipelines load into
(``DATABASE_URL``), so no credentials are duplicated or committed here.
"""

import os
from urllib.parse import urlparse

from dotenv import load_dotenv
from sqlmesh.core.config import (
    Config,
    GatewayConfig,
    ModelDefaultsConfig,
)
from sqlmesh.core.config.connection import PostgresConnectionConfig

load_dotenv()

db_url = urlparse(os.environ["DATABASE_URL"])

gateways = {
    "postgres": GatewayConfig(
        connection=PostgresConnectionConfig(
            host=db_url.hostname,
            port=db_url.port or 5432,
            user=db_url.username,
            password=db_url.password,
            database=db_url.path.lstrip("/"),
        ),
    ),
}

config = Config(
    gateways=gateways,
    default_gateway="postgres",
    model_defaults=ModelDefaultsConfig(
        dialect="postgres",
        start="2026-08-22",
    ),
)
