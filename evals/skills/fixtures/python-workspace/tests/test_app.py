from datetime import UTC, datetime

from ticket_desk.app import Deps, create_app
from ticket_desk.tickets import Priority, Status, Ticket
from ticket_desk.web import Request

NOW = datetime(2026, 3, 2, 9, 30, tzinfo=UTC)


def ticket(ticket_id: str, status: Status = Status.OPEN) -> Ticket:
    return Ticket(ticket_id, "Printer on fire", Priority.NORMAL, status, NOW)


def make_app(*tickets: Ticket):
    return create_app(Deps(now=lambda: NOW, new_id=lambda: "t-new"), tickets)


def test_counts_open_tickets() -> None:
    app = make_app(ticket("t-1"), ticket("t-2", Status.CLOSED), ticket("t-3"))

    response = app.handle(Request("GET", "/tickets/open-count"))

    assert response.status == 200
    assert response.body == {"open": 2}


def test_closes_a_ticket() -> None:
    app = make_app(ticket("t-1"))

    response = app.handle(Request("POST", "/tickets/t-1/close"))

    assert response.status == 200
    assert response.body == {"closed_at": "2026-03-02T09:30:00+00:00"}
    assert app.tickets()[0].status is Status.CLOSED


def test_closing_an_unknown_ticket_is_not_found() -> None:
    app = make_app()

    assert app.handle(Request("POST", "/tickets/t-9/close")).status == 404
