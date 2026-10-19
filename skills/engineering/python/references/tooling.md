# Python tooling defaults

Load this when a project has no tooling yet, or when adding a tool the project
lacks. Where the project already has a tool or a setting, keep it: these are
defaults, not corrections.

## Contents

- Detecting what the project uses
- A complete `pyproject.toml`
- Why each setting
- CI commands

## Detecting what the project uses

| Look for | It means |
|---|---|
| `uv.lock`, `[tool.uv]` | uv: `uv add`, `uv run <cmd>`, `uv sync --locked` |
| `poetry.lock`, `[tool.poetry]` | Poetry: `poetry add`, `poetry run <cmd>` |
| `pdm.lock` | PDM: `pdm add`, `pdm run <cmd>` |
| `requirements*.txt` only | pip + venv; activate `.venv` or call `.venv/bin/python -m <tool>` |
| `[tool.ruff]`, `ruff.toml` | ruff for lint and probably format |
| `[tool.black]`, `[tool.isort]`, `.flake8` | black/isort/flake8; do not add ruff format alongside black |
| `[tool.pyright]`, `pyrightconfig.json`, `[tool.basedpyright]` | pyright or basedpyright |
| `[tool.mypy]`, `mypy.ini` | mypy |
| `.pre-commit-config.yaml` | the hooks are the project's definition of "clean"; run `pre-commit run --all-files` |
| `Makefile`, `noxfile.py`, `tox.ini`, `justfile` | prefer the project's task (`make test`, `nox -s tests`) over calling tools directly |

## A complete `pyproject.toml`

```toml
[project]
name = "orders"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "pydantic>=2.7",
]

[dependency-groups]
dev = [
    "pytest>=8",
    "hypothesis>=6",
    "pyright>=1.1.380",
    "ruff>=0.6",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
target-version = "py312"
line-length = 100
src = ["src", "tests"]

[tool.ruff.lint]
select = [
    "E", "W", "F",   # pycodestyle, pyflakes
    "I",             # import sorting
    "UP",            # pyupgrade: modern syntax for the target version
    "B",             # bugbear: mutable defaults, loop-variable capture, …
    "SIM", "C4", "RET",
    "BLE",           # blind except
    "TRY",           # exception handling style
    "DTZ",           # naive datetimes
    "PTH",           # pathlib over os.path
    "S",             # bandit security checks
    "PT",            # pytest style
    "RUF",
    "ANN",           # missing annotations
]
ignore = [
    "TRY003",        # long messages in exception constructors are fine
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "ANN"]   # assert is how pytest works; fixtures need no annotations

[tool.pyright]
pythonVersion = "3.12"
typeCheckingMode = "strict"
include = ["src", "tests"]
reportMissingTypeStubs = "warning"

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["-ra", "--strict-markers", "--strict-config", "--import-mode=importlib"]
xfail_strict = true
filterwarnings = ["error"]
```

If the project uses mypy instead of pyright:

```toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_unreachable = true
enable_error_code = ["ignore-without-code", "redundant-expr", "truthy-bool", "explicit-override"]
plugins = ["pydantic.mypy"]   # only when pydantic is a dependency
```

## Why each setting

- **`requires-python = ">=3.12"`** lets ruff's `UP` rules and the type checker
  accept `type` aliases, PEP 695 generics and `@override`.
- **`[dependency-groups]`** (PEP 735) keeps development tools out of the
  published package's dependencies; uv installs the `dev` group by default.
- **`typeCheckingMode = "strict"`** reports unknown and partially unknown types,
  which is where `Any` leaks in from untyped libraries. Lower individual rules
  to `"warning"` for a real upstream gap instead of dropping strict mode.
- **`ignore-without-code`** (mypy) makes a bare `# type: ignore` an error.
- **`filterwarnings = ["error"]`** turns deprecation warnings into failures, so
  a removal in the next library release is found by the tests, not by
  production.
- **`--import-mode=importlib`** stops tests from importing the package from the
  source tree by accident instead of the installed one, and allows test files
  with the same name in different folders.
- **`xfail_strict`** fails a test marked `xfail` that starts passing, so stale
  markers are removed.
- **`BLE`, `TRY`, `DTZ`, `PTH`, `B`** catch most of the rules in the skill's
  Errors and I/O sections mechanically.

## CI commands

With uv:

```sh
uv sync --locked
uv run ruff format --check
uv run ruff check
uv run pyright
uv run pytest
```

`--locked` fails if `uv.lock` is out of date with `pyproject.toml`, instead of
silently resolving new versions in CI.
