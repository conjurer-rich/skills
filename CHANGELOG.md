# @conjurer-rich/skills

## 5.1.0

### Minor Changes

- f01dffc: `engineering-practice` now carries the engineering guidelines itself instead of pointing at a copy of the old `CLAUDE.md`. Policy lives in its `SKILL.md`; which skill to load for which work lives in `references/routing.md`, merged from both old routing lists and limited to skills that are shipped or marked "when installed".

  New `global/CLAUDE.md` (with `global/AGENTS.md` linked to it) and `scripts/install-global`, which links it to `~/.claude/CLAUDE.md` and, when Codex or OpenCode are installed, to their `AGENTS.md`. It backs up any existing file and retires the old `~/.claude/base-CLAUDE.md`. Run it once from a clone; `--copy` where symlinks are unavailable.

## 5.0.0

### Major Changes

- 5d6ece3: craft moves to its own repository, `conjurer-rich/skills`, and its own marketplace, `conjurer`.

  Reinstall it: `claude plugin uninstall craft@conjurer-dotfiles`, then `claude plugin marketplace add conjurer-rich/skills` and `claude plugin install craft@conjurer`. Skill, agent and command names are unchanged (`craft:<name>`).

  - Skills are grouped into `skills/engineering`, `architecture`, `delivery` and `writing`. Eleven unused items move to `shelf/`, which is kept in the repository but not installed: `bff-design`, `cli-design`, `graph-engineering`, `panel-review`, `production-parity-skill-builder`, `render-code-shape`, `teach-me`, the `docs-guardian`, `progress-guardian`, `ts-enforcer` and `use-case-data-patterns` agents, and `/setup`. `folder-structure` is deprecated.
  - The PR-readiness evidence model moves from `panel-review` to `mutation-testing/references/pr-readiness.md`.
  - `engineering-practice` reads its guidelines from its own `references/guidelines.md`.
  - The Stop hook ships with the plugin (`hooks/hooks.json`) instead of being installed into `settings.json`.
  - `LICENSE` keeps Paul Hammond's notice and adds Richard Allen's; `ACKNOWLEDGEMENTS.md` lists every adapted source.
