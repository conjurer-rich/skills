# Provenance

This repository started on 2026-10-08 as a fresh import, not a fork. It has no
git history in common with `citypaul/.dotfiles` or `conjurer-rich/.dotfiles`.

- **Source:** [`conjurer-rich/.dotfiles@927975e`](https://github.com/conjurer-rich/.dotfiles/tree/927975e1f48438c58ea4e145fc7874e76dcce6a0/claude/.claude),
  directory `claude/.claude/`, released there as craft 4.30.3.
- **That fork's upstream:** [`citypaul/.dotfiles`](https://github.com/citypaul/.dotfiles),
  merged into the fork up to the fork's `main` at that commit.
- **Plan:** [`plans/skills-repo-extraction.md`](https://github.com/conjurer-rich/.dotfiles/blob/claude/pensive-faraday-v2iuqy/plans/skills-repo-extraction.md)
  in the fork, which records the decisions (D1–D12) behind this layout.

Full history for every imported file stays readable in the fork.

## Triage at import

Usage came from `scripts/skill-usage.py` over about a month of Claude Code
transcripts (Claude Code keeps 30 days by default).

| Where | Items |
| --- | --- |
| **Shipped skills (45)** | used, a used item depends on them, or kept as dormant-but-useful: see `.claude-plugin/plugin.json` |
| **Shipped agents (5)** | `tdd-guardian`, `refactor-scan`, `twelve-factor-audit`, `adr`, `learn` |
| **Shipped commands (3)** | `/delegate`, `/plan`, `/continue` |
| **Shelf** (in the repository, not installed) | skills `bff-design`, `cli-design`, `graph-engineering`, `panel-review`, `production-parity-skill-builder`, `render-code-shape`, `teach-me`; agents `docs-guardian`, `progress-guardian`, `ts-enforcer`, `use-case-data-patterns`; command `/setup` |
| **Deprecated** | `folder-structure` (alias of `structure-codebase`; deleted after one release) |

## Changes made during the import

- Files moved into `skills/<bucket>/<name>`, `shelf/` and
  `skills/deprecated/`; relative links between buckets rewritten.
- `panel-review/references/pr-readiness.md` moved to
  `mutation-testing/references/pr-readiness.md`, because `tdd`,
  `planning` and the agents rely on its evidence-freshness model and
  `panel-review` is shelved.
- References from shipped files to shelved items removed or reworded.
- `CLAUDE.md` copied to
  `skills/engineering/engineering-practice/references/guidelines.md`, which
  the skill now reads instead of `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md`.
- The Stop hook moved from `settings.json` into `hooks/hooks.json`.

## After the import

- 5.1.0: `references/guidelines.md` folded into `engineering-practice` itself
  (`SKILL.md` for policy, `references/routing.md` for skill routing, merged
  with the fork's `CLAUDE.rich.md` routing and pruned to installed skills).
  The fork's personal preferences moved to `global/CLAUDE.md`.
