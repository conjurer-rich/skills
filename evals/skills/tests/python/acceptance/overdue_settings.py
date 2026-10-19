# Hidden acceptance test: overdue tickets with settings from the environment.
# Pins only the route, the two variable names and build_app(initial).
from datetime import UTC, datetime, timedelta

import pytest

from ticket_desk.main import build_app
from ticket_desk.tickets import Priority, Status, Ticket
from ticket_desk.web import Request


def opened(ticket_id: str, minutes_ago: int, status: Status = Status.OPEN) -> Ticket:
    at = datetime.now(UTC) - timedelta(minutes=minutes_ago)
    return Ticket(ticket_id, "Printer on fire", Priority.NORMAL, status, at)


TICKETS = (
    opened("t-old", 120),
    opened("t-new", 5),
    opened("t-mid", 45),
    opened("t-done", 300, Status.CLOSED),
)


def clear(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TICKET_DESK_OVERDUE_MINUTES", raising=False)
    monkeypatch.delenv("TICKET_DESK_ESCALATION_TEAM", raising=False)


def overdue(monkeypatch: pytest.MonkeyPatch, **env: str) -> object:
    clear(monkeypatch)
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    app = build_app(TICKETS)
    response = app.handle(Request("GET", "/tickets/overdue"))
    assert response.status == 200
    return response.body


def test_defaults_when_nothing_is_set(monkeypatch: pytest.MonkeyPatch) -> None:
    assert overdue(monkeypatch) == {"team": "support", "ticket_ids": ["t-old"]}


def test_uses_the_configured_threshold_and_team(monkeypatch: pytest.MonkeyPatch) -> None:
    body = overdue(
        monkeypatch, TICKET_DESK_OVERDUE_MINUTES="30", TICKET_DESK_ESCALATION_TEAM="tier-2"
    )

    assert body == {"team": "tier-2", "ticket_ids": ["t-old", "t-mid"]}


@pytest.mark.parametrize(
    "value", ["soon", "0", "-5", "1.5"], ids=["word", "zero", "negative", "fraction"]
)
def test_refuses_to_start_with_a_bad_threshold(
    monkeypatch: pytest.MonkeyPatch, value: str
) -> None:
    clear(monkeypatch)
    monkeypatch.setenv("TICKET_DESK_OVERDUE_MINUTES", value)

    with pytest.raises(Exception, match=r"(?i)overdue_minutes"):
        build_app(TICKETS)
