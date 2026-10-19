from collections.abc import Iterable, Sequence
from dataclasses import dataclass, replace
from datetime import datetime
from enum import StrEnum


class Priority(StrEnum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"


class Status(StrEnum):
    OPEN = "open"
    IN_PROGRESS = "in-progress"
    CLOSED = "closed"


@dataclass(frozen=True)
class Ticket:
    id: str
    title: str
    priority: Priority
    status: Status
    opened_at: datetime


def open_ticket(tickets: Iterable[Ticket], ticket: Ticket) -> list[Ticket]:
    return [*tickets, ticket]


def close_ticket(tickets: Iterable[Ticket], ticket_id: str) -> list[Ticket]:
    return [
        replace(ticket, status=Status.CLOSED) if ticket.id == ticket_id else ticket
        for ticket in tickets
    ]


def find_ticket(tickets: Sequence[Ticket], ticket_id: str) -> Ticket | None:
    return next((ticket for ticket in tickets if ticket.id == ticket_id), None)


def open_count(tickets: Iterable[Ticket]) -> int:
    return sum(1 for ticket in tickets if ticket.status is Status.OPEN)
