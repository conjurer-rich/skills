---
"@conjurer-rich/skills": minor
---

python: a new skill for writing, reviewing and refactoring Python 3.12+. It follows the repository's own tools first (with uv, ruff, pyright strict and pytest as defaults, and a complete `pyproject.toml` in `references/tooling.md`), and covers strict typing, parsing untrusted data into typed models at the boundary, one owner per value set, `NewType` identifiers, frozen dataclasses, Protocols, error handling, UTF-8 I/O and aware datetimes, async and pytest. `engineering-practice` gains a Python section that routes to it, and `ask` lists it beside `typescript-strict`. A `python` quality suite under `evals/skills` (four cases, proven against a reference solution) measures the skill; `run-quality.sh` now builds a fixture with `uv sync --locked` when it has a `uv.lock`.
