# Hidden acceptance test: goodwill credits from billing. Pins only the two
# routes, create_app(deps, initial) and the JSON shapes in the request.
import json
from datetime import UTC, datetime

import pytest

from ticket_desk.app import App, Deps, create_app
from ticket_desk.tickets import Priority, Status, Ticket
from ticket_desk.web import Request

NOW = datetime(2026, 3, 2, 9, 30, tzinfo=UTC)


def make_app() -> App:
    tickets = [
        Ticket(f"t-{n}", "Printer on fire", Priority.NORMAL, Status.OPEN, NOW) for n in (1, 2)
    ]
    return create_app(Deps(now=lambda: NOW, new_id=lambda: "t-new"), tickets)


def credit(app: App, **fields: object) -> int:
    body = {"ticket_id": "t-1", "customer_id": "cus-7", "amount": "1.00", **fields}
    return app.handle(Request("POST", "/credits", json.dumps(body).encode())).status


def total(app: App, customer_id: str) -> object:
    response = app.handle(Request("GET", f"/customers/{customer_id}/credits"))
    assert response.status == 200
    return response.body


def test_totals_credits_per_customer_to_the_penny() -> None:
    app = make_app()

    assert credit(app, amount="0.10") == 201
    assert credit(app, amount="0.20", ticket_id="t-2") == 201
    assert credit(app, amount="12.5", customer_id="cus-8") == 201

    assert total(app, "cus-7") == {"customer_id": "cus-7", "total": "0.30"}
    assert total(app, "cus-8") == {"customer_id": "cus-8", "total": "12.50"}


def test_a_customer_with_no_credits_has_a_zero_total() -> None:
    assert total(make_app(), "cus-9") == {"customer_id": "cus-9", "total": "0.00"}


def test_an_unknown_ticket_is_not_found() -> None:
    assert credit(make_app(), ticket_id="t-99") == 404


@pytest.mark.parametrize(
    "fields",
    [
        {"ticket_id": "cus-7", "customer_id": "t-1"},
        {"customer_id": "7"},
        {"amount": "-1.00"},
        {"amount": "0"},
        {"amount": "1.005"},
        {"amount": "lots"},
        {"amount": None},
    ],
    ids=["swapped-ids", "bad-customer-id", "negative", "zero", "sub-penny", "not-a-number", "null"],
)
def test_rejects_an_unusable_credit(fields: dict[str, object]) -> None:
    app = make_app()

    assert credit(app, **fields) == 400
    assert total(app, "cus-7") == {"customer_id": "cus-7", "total": "0.00"}
