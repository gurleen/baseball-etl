"""Pushover failure notifications for Prefect flows, via Prefect's
`CustomWebhookNotificationBlock`.

Run once (and again whenever PUSHOVER_TOKEN/PUSHOVER_USER change) to
create/update the block that every flow's `on_failure` hook in `flows.py`
loads at run time:

    PUSHOVER_TOKEN=... PUSHOVER_USER=... uv run python -m baseball_etl.notifications

Get a token/user key from https://pushover.net (an "Application" token plus
your account's user key).
"""

import os

from prefect.blocks.notifications import CustomWebhookNotificationBlock
from prefect.client.schemas.objects import FlowRun
from prefect.flows import Flow
from prefect.states import State

PUSHOVER_BLOCK_NAME = "pushover"


def register_pushover_block() -> None:
    block = CustomWebhookNotificationBlock(
        name=PUSHOVER_BLOCK_NAME,
        url="https://api.pushover.net/1/messages.json",
        method="POST",
        form_data={
            "token": "{{tokenFromSecrets}}",
            "user": "{{userFromSecrets}}",
            "title": "{{subject}}",
            "message": "{{body}}",
        },
        secrets={
            "tokenFromSecrets": os.environ["PUSHOVER_TOKEN"],
            "userFromSecrets": os.environ["PUSHOVER_USER"],
        },
    )
    block.save(name=PUSHOVER_BLOCK_NAME, overwrite=True)


def notify_failure(flow: Flow, flow_run: FlowRun, state: State) -> None:
    """`on_failure` hook: attach to any `@flow` to Pushover-alert on failure."""
    block = CustomWebhookNotificationBlock.load(PUSHOVER_BLOCK_NAME)
    block.notify(
        subject=f"baseball-etl: {flow.name} failed",
        body=f"Flow run {flow_run.name!r} entered state {state.name!r}.\n"
        f"flow_run_id={flow_run.id}",
    )


if __name__ == "__main__":
    register_pushover_block()
