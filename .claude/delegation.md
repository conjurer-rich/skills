# Delegation settings

Read by `/delegate` (the `delegating-github-issues` skill) and by
`scripts/delegate-loop`. Parameters left out take the skill's defaults.

## Parameters

| Parameter | Value |
|---|---|
| `label` | `agent-ready` |
| `rank_labels` | `p1`, `p2` |
| `max_worktrees` | 1 |
| `pre_pr_gate` | `./test/run.sh`, then `pnpm changeset status --since origin/main` |
| `risk_paths` | `.claude-plugin/**`, `package.json`, `hooks/**`, `global/**`, `scripts/version.sh` |
| `walkthrough` | off |
| `land` | on |

## Verification scope

This repository is the `craft` plugin: Markdown skills, shell and Python
checks, and a few scripts. It has no build, typecheck or unit-test runner
beyond `./test/run.sh`, and no mutation tool.

- Run `./test/run.sh` once, at the end, with its output written to a file;
  report the summary and any `FAIL` lines. It covers layout, licensing,
  portability, frontmatter and every script's tests, and is the complete suite
  CI runs.
- While working, run only the `test/*.sh` file for what you changed (for
  example `bash test/delegate-status.sh`).
- A change to a script (`scripts/`, a skill's `scripts/`, `hooks/`) follows
  RED before GREEN in its `test/*.sh` file. A prose-only change to a skill
  needs no new test; record `Mutation gate: N/A, prose only` and name the
  checks that cover it.
- Run `pnpm changeset status --since origin/main` and confirm it passes.

## Project rules

- Follow `CLAUDE.md` at the repository root.
- Add a changeset (`pnpm changeset`) for anything a user of the plugin would
  notice; use `pnpm changeset --empty` for a change no user sees. Never edit
  `version` in `package.json` or `.claude-plugin/plugin.json` by hand.
- A new shipped skill lives at `skills/<bucket>/<name>/SKILL.md`, is listed in
  `.claude-plugin/plugin.json`, and has an `agents/openai.yaml`. Agents under
  `agents/` are discovered by default and are never listed in `plugin.json`.
- Never create a `.claude/skills/` directory in this repository.
- Shipped files never route to anything under `shelf/`.
- Name capabilities, not one harness's tools, in skill text; where only a
  Claude Code tool will do, say so in a note labelled "Claude Code:".
