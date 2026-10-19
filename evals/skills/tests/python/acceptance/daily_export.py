# Hidden acceptance test: the daily CSV export. Pins only
# export_today(tickets, directory) in ticket_desk.reports and the file format.
import csv
from datetime import UTC, datetime, timedelta
from pathlib import Path

from ticket_desk.reports import export_today
from ticket_desk.tickets import Priority, Status, Ticket


def test_writes_todays_tickets_as_utf8_csv(tmp_path: Path) -> None:
    now = datetime.now(UTC).replace(microsecond=0)
    tickets = [
        Ticket("t-1", "Café till prints ☕ instead of £", Priority.HIGH, Status.OPEN, now),
        Ticket("t-2", "Old, already handled", Priority.LOW, Status.CLOSED, now - timedelta(days=2)),
        Ticket("t-3", 'Says "Zürich, CH" twice', Priority.NORMAL, Status.IN_PROGRESS, now),
    ]

    path = export_today(tickets, tmp_path)

    assert Path(path) == tmp_path / f"tickets-{now.date().isoformat()}.csv"
    with Path(path).open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    assert rows[0] == ["id", "title", "priority", "status", "opened_at"]
    assert [row[:4] for row in rows[1:]] == [
        ["t-1", "Café till prints ☕ instead of £", "high", "open"],
        ["t-3", 'Says "Zürich, CH" twice', "normal", "in-progress"],
    ]
    assert all(datetime.fromisoformat(row[4]) == now for row in rows[1:])
