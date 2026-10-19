# Hidden acceptance test: tickets from the web form. Pins only the route,
# create_app(deps, initial), Deps(now, new_id) and app.tickets().
import json
from datetime import UTC, datetime

import pytest

from ticket_desk.app import App, Deps, create_app
from ticket_desk.tickets import Priority, Status
from ticket_desk.web import Request, Response

NOW = datetime(2026, 3, 2, 9, 30, tzinfo=UTC)


def post(body: bytes) -> tuple[App, Response]:
    app = create_app(Deps(now=lambda: NOW, new_id=lambda: "t-42"))
    return app, app.handle(Request("POST", "/tickets", body))


def test_opens_a_ticket_with_the_given_priority() -> None:
    app, response = post(json.dumps({"title": "Printer on fire", "priority": "high"}).encode())

    assert response.status == 201
    assert json.loads(json.dumps(response.body, default=str)) == {
        "id": "t-42",
        "title": "Printer on fire",
        "priority": "high",
        "status": "open",
        "opened_at": "2026-03-02T09:30:00+00:00",
    }
    [ticket] = app.tickets()
    assert ticket.id == "t-42"
    assert ticket.priority is Priority.HIGH
    assert ticket.status is Status.OPEN
    assert ticket.opened_at == NOW


def test_priority_defaults_to_normal() -> None:
    app, response = post(json.dumps({"title": "Printer on fire"}).encode())

    assert response.status == 201
    assert app.tickets()[0].priority is Priority.NORMAL


@pytest.mark.parametrize(
    "body",
    [
        b"not json",
        b"[]",
        b'{"priority": "high"}',
        b'{"title": "   "}',
        b'{"title": 7}',
        b'{"title": "Printer on fire", "priority": "urgent"}',
        b'{"title": "Printer on fire", "priority": null}',
    ],
    ids=["not-json", "array", "no-title", "blank-title", "number-title", "unknown-priority", "null-priority"],
)
def test_rejects_an_unusable_request(body: bytes) -> None:
    app, response = post(body)

    assert response.status == 400
    assert app.tickets() == ()
