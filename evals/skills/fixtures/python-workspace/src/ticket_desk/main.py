from collections.abc import Iterable
from datetime import UTC, datetime
from uuid import uuid4

from ticket_desk.app import App, Deps, create_app
from ticket_desk.tickets import Ticket


def build_app(initial: Iterable[Ticket] = ()) -> App:
    """Wire the app for production."""
    deps = Deps(now=lambda: datetime.now(UTC), new_id=lambda: f"t-{uuid4().hex[:8]}")
    return create_app(deps, initial)
