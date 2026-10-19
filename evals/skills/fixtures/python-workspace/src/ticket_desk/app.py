from collections.abc import Callable, Iterable
from dataclasses import dataclass
from datetime import datetime

from ticket_desk.tickets import Ticket, close_ticket, find_ticket, open_count
from ticket_desk.web import Request, Response, Router


@dataclass(frozen=True)
class Deps:
    now: Callable[[], datetime]
    new_id: Callable[[], str]


class App:
    def __init__(self, router: Router, tickets: Callable[[], tuple[Ticket, ...]]) -> None:
        self._router = router
        self._tickets = tickets

    def handle(self, request: Request) -> Response:
        return self._router.handle(request)

    def tickets(self) -> tuple[Ticket, ...]:
        return self._tickets()


def create_app(deps: Deps, initial: Iterable[Ticket] = ()) -> App:
    tickets = list(initial)
    router = Router()

    @router.route("GET", "/tickets/open-count")
    def count_open(request: Request) -> Response:
        return Response(200, {"open": open_count(tickets)})

    @router.route("POST", "/tickets/{id}/close")
    def close(request: Request) -> Response:
        ticket_id = request.params["id"]
        if find_ticket(tickets, ticket_id) is None:
            return Response(404)
        tickets[:] = close_ticket(tickets, ticket_id)
        return Response(200, {"closed_at": deps.now().isoformat()})

    return App(router, lambda: tuple(tickets))
