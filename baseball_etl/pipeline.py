"""Entry point for loading the Chadwick Bureau register into Postgres."""

import os

import dlt
from dotenv import load_dotenv

from baseball_etl.sources.chadwick_register import chadwick_register

load_dotenv()


def run() -> None:
    pipeline = dlt.pipeline(
        pipeline_name="chadwick_register",
        destination=dlt.destinations.postgres(credentials=os.environ["DATABASE_URL"]),
        dataset_name="raw",
    )
    load_info = pipeline.run(chadwick_register())
    print(load_info)


if __name__ == "__main__":
    run()
