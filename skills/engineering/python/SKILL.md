---
name: python
description: Use for any code change in a Python codebase (a pyproject.toml, .py files) — adding an endpoint, route, handler, setting, export or feature, fixing a bug, reviewing or refactoring, adding a module, script, CLI or service, changing pyproject.toml, or writing pytest tests — even when the request never mentions Python, types or style. Python 3.12+ good practice — tooling that follows the repository first (defaults uv, ruff, pyright strict, pytest), strict static typing, parsing untrusted data into typed models at trust boundaries, one owner per value set, NewType for interchangeable primitives, frozen dataclasses, Protocols, exception handling, explicit encodings and aware datetimes. For immutability and pure-function patterns see functional; for test design see testing and tdd.
---

# Python

## Core Rules

1. **Follow the repository's tools before reaching for defaults.** Read `pyproject.toml`, the lockfile (`uv.lock`, `poetry.lock`, `pdm.lock`, `requirements*.txt`), pre-commit config and CI before choosing a command. Run tools the way the project runs them (`uv run pytest`, `poetry run`, `make test`). Never add a second formatter, linter, type checker or package manager next to one the project already has
2. **Type everything the type checker can see, and keep it clean in strict mode.** Annotate every function signature, including `-> None`. No bare `Any`, no unexplained `cast`, no blanket `# type: ignore`
3. **Parse untrusted data into typed objects at the boundary.** HTTP bodies, JSON files, environment variables, CLI arguments, queue messages and third-party responses become a validated model before any other code touches them. Internal code takes those models, never `dict[str, Any]`
4. **Give every fixed value set one owner.** Before writing a `Literal[...]`, an enum, or an `in ("a", "b")` check, search for an existing declaration and derive from it
5. **Catch only what you can handle, and keep the cause.** No bare `except:`, no `except Exception: pass`, and `raise ... from err` when translating
6. **Two ids that could be swapped are two types.** When one payload or signature carries two identifiers (or amounts) of the same primitive type, declare a `NewType` for each before writing the model, and confer it only after validation. A format check on `str` fields catches bad input, not swapped arguments inside your code

---

## Tooling: Repository First, Then Defaults

Read what the project already uses and match it. The defaults below apply only where the project has not chosen; see `references/tooling.md` for a complete `pyproject.toml` and the reasoning behind each setting.

| Concern | Default when the project has none |
|---|---|
| Environment, dependencies, lockfile | `uv` (`uv add`, `uv add --dev`, `uv run`, commit `uv.lock`, `uv sync --locked` in CI) |
| Lint and format | `ruff check` and `ruff format` |
| Type checking | `pyright` in strict mode (or `mypy --strict` if the project already uses mypy) |
| Tests | `pytest` |
| Project metadata and tool config | One `pyproject.toml`; no `setup.py`, `setup.cfg` or stray `.ini` files for new projects |
| Layout | `src/<package>/` with `tests/` beside `src/` |

When you change code, run the project's formatter, linter, type checker and tests before calling the work done. A type checker you did not run proves nothing.

Do not install packages into the global interpreter or with `pip install` inside a uv or Poetry project; add them through the project's tool so the lockfile records them.

---

## Typing

### Modern syntax (3.12+)

```python
# ✅ Built-in generics, | unions, PEP 695 type parameters and aliases
type UserIndex = dict[UserId, User]

def first[T](items: Sequence[T]) -> T | None:
    return items[0] if items else None

# ❌ Legacy forms in new code
from typing import Dict, List, Optional, TypeVar, Union
T = TypeVar("T")
def first(items: List[T]) -> Optional[T]: ...
```

Use `Self` for methods returning their own class and `@override` (from `typing`) on every method that overrides a parent's, so a renamed base method breaks the build instead of silently orphaning the override.

### Accept abstract, return concrete

Parameters take the narrowest protocol the function needs (`Iterable`, `Sequence`, `Mapping` from `collections.abc`); return types name what is actually returned (`list`, `dict`, a dataclass). A function that only reads a mapping should not demand a mutable `dict`, and its callers then cannot accidentally rely on mutating it.

### `Any`, `cast` and ignores

- `Any` switches the checker off for everything it touches and spreads silently. Use `object` when you accept anything and will narrow, a `TypeVar` when the type flows through, or a `Protocol` when you need certain methods.
- Untyped third-party code: contain it in one adapter module that converts its results into your types. Prefer installing the library's stubs (`types-…`) over ignoring it.
- `cast(T, x)` is an unchecked assertion. Prefer narrowing with `isinstance`, a `TypeGuard`/`TypeIs` function, or validation. Where a cast is unavoidable, comment why.
- Suppressions name the rule and the reason: `# pyright: ignore[reportUnknownMemberType]  # stub missing upstream: <link>` or `# type: ignore[attr-defined]  # …`. A bare `# type: ignore` hides every future error on that line.

### Exhaustive branching

When code branches over a closed set (an enum, a `Literal`, a union of classes), make the checker prove every case is handled:

```python
from typing import assert_never

def label(state: OrderState) -> str:
    match state:
        case OrderState.DRAFT:
            return "Draft"
        case OrderState.PLACED:
            return "Placed"
        case OrderState.SHIPPED:
            return "Shipped"
        case _:
            assert_never(state)  # adding a member to OrderState is now a type error here
```

---

## Trust Boundaries: Parse, Don't Pass Dicts

Validate once where data enters, then pass typed objects inward. Inside the boundary, functions trust their inputs and do not re-check them.

Use the validation library the project already has. Pydantic v2 is the default for new projects; `msgspec` or `attrs` + `cattrs` are fine where already adopted. Plain dataclasses plus a hand-written parse function are fine for small, dependency-free code.

```python
from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, StringConstraints

# Required and not blank: strip first, so "   " is rejected too.
# `Field(min_length=1)` alone lets whitespace through.
type NonBlank = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]

class CreateUserRequest(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    email: EmailStr
    name: NonBlank

# At the boundary: raises ValidationError with every problem listed
request = CreateUserRequest.model_validate_json(body)
create_user(request)  # internal code takes the model, not the dict
```

```python
# ❌ The dict travels inward and every caller guesses at its keys
def create_user(payload: dict[str, Any]) -> None:
    email = payload.get("email", "")
```

- **Configuration** is a boundary: load environment variables once at startup into a typed settings object (`pydantic-settings`, or a frozen dataclass built by one function) and pass it in. Do not call `os.environ` from business logic.
- **Same shape, different owners**: do not import another service's or bounded context's model because its fields match today. Each boundary owns and validates its own contract.
- **Internal values** created and consumed inside one trusted process need no validation library: a frozen dataclass with a validating constructor is the clearer owner.

---

## One Owner per Value Set

A fixed set of values (states, roles, currencies, event types) is declared once, and every type, validator, CLI choice list and database check derives from that declaration.

```python
from enum import StrEnum

# ✅ One owner; the model, the CLI and the checks all derive from it
class OrderState(StrEnum):
    DRAFT = "draft"
    PLACED = "placed"
    SHIPPED = "shipped"

class Order(BaseModel):
    state: OrderState  # Pydantic validates against the enum

parser.add_argument("--state", choices=[s.value for s in OrderState])

# ❌ Three owners that drift apart the first time a state is added
STATES = ["draft", "placed", "shipped"]
state: Literal["draft", "placed", "shipped"]
if state in ("draft", "placed"): ...
```

If the set is already declared as a `Literal` alias, derive the runtime list with `typing.get_args(OrderStateLiteral)` rather than writing the members a second time. If the codebase already has the set, widen that declaration; do not leave a second copy behind.

---

## Distinct Types for Interchangeable Primitives

When two values share an underlying type and could be swapped without the checker noticing (a user ID and an order ID, an amount and a rate), give each a `NewType` and confer it only in a validating constructor. Reach for this whenever a payload carries two ids, ids have recognisable prefixes, or a bug report says values arrived the wrong way round. Validating each field's format (`pattern=r"^t-"`) rejects bad input at the boundary, but the model's fields are still plain `str` and every function inside can still be called with them swapped.

```python
from decimal import Decimal
from typing import NewType

UserId = NewType("UserId", str)
OrderId = NewType("OrderId", str)

def to_user_id(raw: str) -> UserId:
    if not raw.startswith("usr_"):
        raise ValueError(f"not a user id: {raw!r}")
    return UserId(raw)

def to_order_id(raw: str) -> OrderId: ...  # same shape: check "ord_", raise, confer

def cancel(order_id: OrderId, by: UserId) -> None: ...

cancel(to_user_id("usr_1"), to_order_id("ord_9"))  # ❌ type error: arguments swapped
```

Once a validating constructor exists, it is the only place the `NewType` is called. Every other entry point, such as a path parameter, query string, CLI argument or row read back from storage, goes through `to_user_id(raw)`, never `UserId(raw)`.

At a pydantic boundary, type the fields with the `NewType`s and let the validating constructors confer them, so the parsed model already carries distinct types:

```python
from typing import Annotated

from pydantic import AfterValidator, BaseModel

class CancelRequest(BaseModel):
    order_id: Annotated[OrderId, AfterValidator(to_order_id)]
    user_id: Annotated[UserId, AfterValidator(to_user_id)]
```

**Money is never `float`.** Use integer minor units or `Decimal` constructed from a string (`Decimal("19.99")`, not `Decimal(19.99)`), and round with a named mode (`quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)`).

---

## Data and Behaviour

### Value objects: frozen dataclasses

```python
from dataclasses import dataclass, field

@dataclass(frozen=True, slots=True, kw_only=True)
class Order:
    id: OrderId
    lines: tuple[OrderLine, ...]            # tuple, not list, so it cannot be mutated through the instance
    tags: frozenset[str] = frozenset()

    def __post_init__(self) -> None:
        if not self.lines:
            raise ValueError("an order needs at least one line")
```

- `frozen=True` makes the instance immutable and hashable; use `dataclasses.replace(order, …)` to produce a changed copy. For immutability patterns in depth, see the `functional` skill.
- `kw_only=True` stops callers swapping same-typed positional fields.
- **Never use a mutable default** (`def f(items=[])`, `items: list[str] = []`). Use `None` and create inside, or `field(default_factory=list)`.
- Prefer a dataclass or model over a tuple or dict once a value has more than two fields or crosses a function boundary.

### Ports: `Protocol` over `ABC`

Describe a dependency by the methods you call on it with a `typing.Protocol`. Implementations need not inherit from it, so tests can pass a small fake without touching production classes. Use an `ABC` only when subclasses genuinely share implementation.

```python
class UserRepository(Protocol):
    def get(self, user_id: UserId) -> User | None: ...
    def save(self, user: User) -> None: ...
```

### Functions and modules

- Pass dependencies in as parameters; avoid module-level singletons and work done at import time (network calls, reading files, reading the environment). Importing a module should be cheap and side-effect free.
- Use keyword-only parameters (`def send(*, to: Email, retry: bool = False)`) for boolean flags and for any two adjacent parameters of the same type.
- Scripts and CLIs put their work in `main()` behind `if __name__ == "__main__":` and return an exit code.

---

## Errors

```python
class OrderError(Exception):
    """Base for errors callers of this package may handle."""

class OrderNotFound(OrderError):
    def __init__(self, order_id: OrderId) -> None:
        super().__init__(f"order {order_id} not found")
        self.order_id = order_id

try:
    row = db.fetch_order(order_id)
except psycopg.OperationalError as err:
    raise OrderUnavailable(order_id) from err   # keep the cause
```

- Catch the narrowest exception you can act on. `except Exception` belongs only at a process boundary (a request handler, a worker loop, `main`), where you log with `logger.exception(...)` and translate to a response or exit code.
- Never swallow: no `except: pass`, no `except Exception: return None` that turns a bug into a missing value.
- Define a small exception hierarchy per package so callers can catch `OrderError` without knowing every subclass.
- Use `contextlib.suppress(FileNotFoundError)` only when ignoring that one error really is the intent.

---

## I/O, Time and Resources

- **Always pass `encoding="utf-8"`** to `open`, `Path.read_text` and `Path.write_text`. The default encoding is platform-dependent and is not UTF-8 on Windows.
- Use `pathlib.Path`, not string paths and `os.path`.
- Hold every file, lock, connection and client in a `with` (or `async with`) block.
- **Datetimes are timezone-aware.** `datetime.now(UTC)`, never `datetime.utcnow()` (deprecated in 3.12 and returns a naive value) or a bare `datetime.now()` for stored or compared times. Pass a clock in where tests need to control time.
- Log with `logger = logging.getLogger(__name__)` and lazy arguments (`logger.info("saved %s", order_id)`); libraries never call `print` or configure logging. See the `observability` skill for what to log.
- `subprocess.run([...], check=True)` with a list of arguments; no `shell=True` with interpolated input. No `eval`/`exec`, no `pickle.load` or `yaml.load` on untrusted data (`yaml.safe_load`).

### Async

- Never call blocking I/O (`requests`, `time.sleep`, file reads of unknown size) inside `async def`; use an async client or `asyncio.to_thread`.
- Prefer `asyncio.TaskGroup` to bare `create_task`; a task you create without keeping a reference can be garbage-collected mid-flight and its exception is lost.
- Use `asyncio.timeout(...)` around anything that waits on the network.

---

## Tests with pytest

General test design lives in the `testing` and `tdd` skills. Python specifics:

- Plain `assert`; pytest rewrites it to show both sides. No `unittest.TestCase` in new tests unless the suite already uses it.
- `@pytest.mark.parametrize` with `ids=` for tables of cases, instead of loops inside one test.
- `pytest.raises(OrderNotFound, match="ord_9")`: name the exception type and check the message.
- Built-in fixtures before mocks: `tmp_path` for files, `monkeypatch.setenv` for environment, `caplog` for logging. Pass fakes that satisfy the `Protocol` rather than patching module internals with `mock.patch`.
- Fixtures build collaborators; tests stay readable on their own. Avoid deep fixture chains and `autouse` fixtures that hide setup.
- Use Hypothesis for properties of parsers, serialisers and pure transformations (round-trips, invariants).
- Type-check the tests as well. They are the first callers of your API.

---

## Summary Checklist

When writing or reviewing Python, verify:

- [ ] Commands and tools match what the repository already uses; nothing new installed globally or outside the lockfile
- [ ] Formatter, linter, type checker and tests were actually run and are clean
- [ ] Every signature is annotated; no bare `Any`, unexplained `cast`, or `# type: ignore` without a rule code and reason
- [ ] 3.12 syntax: `list[int]`, `X | None`, `type` aliases, `def f[T]`; `@override` on overrides
- [ ] Untrusted input is parsed into a typed model at the boundary; no `dict[str, Any]` travels inward; config is loaded once
- [ ] A value set the codebase already declares is derived from, never spelled out again
- [ ] Same-typed identifiers and amounts are `NewType`s conferred by a validating constructor; money is never `float`
- [ ] Value objects are frozen dataclasses; no mutable default arguments
- [ ] Exceptions are narrow, never swallowed, and chained with `from`
- [ ] `encoding="utf-8"` on every text I/O call; datetimes are timezone-aware
- [ ] For immutability, pure functions, composition: see the `functional` skill
