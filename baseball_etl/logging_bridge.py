"""Forwards loguru records into the standard `logging` module, under the
"baseball_etl" logger name, so Prefect's run-context log handler (which only
attaches to stdlib loggers) picks them up. Import this once before any flow
runs; `flows.py` does that at module load time.

The worker also needs `PREFECT_LOGGING_EXTRA_LOGGERS=baseball_etl` set (see
Dockerfile) so Prefect actually attaches its handler to this logger name.
"""

import logging
import sys

from loguru import logger

_BRIDGE_LOGGER = logging.getLogger("baseball_etl")


class _PropagateHandler(logging.Handler):
    def emit(self, record: logging.LogRecord) -> None:
        _BRIDGE_LOGGER.handle(record)


def install() -> None:
    logger.remove()
    logger.add(sys.stderr, level="INFO")
    logger.add(_PropagateHandler(), format="{message}", level="INFO")
