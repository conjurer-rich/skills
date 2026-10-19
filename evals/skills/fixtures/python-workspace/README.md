# ticket-desk

Backend for the support-desk app. **This service is written in strictly typed Python
and treats type safety as a requirement, not a style preference.**

`src/ticket_desk/tickets.py` holds the ticket rules, `src/ticket_desk/app.py` builds the
app, `src/ticket_desk/main.py` wires it for production, and `src/ticket_desk/web.py` is a
stand-in for the web framework we do not own.

The project is managed with uv; everything is already installed.

- `uv run pytest` runs the tests.
- `uv run basedpyright` type-checks `src/` and `tests/` in strict mode.
- `uv run ruff check` lints; `uv run ruff format` formats.
