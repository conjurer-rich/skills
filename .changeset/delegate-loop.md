---
"@conjurer-rich/skills": minor
---

delegating-github-issues: a harness-neutral runner, `scripts/delegate-loop`, beside `/loop /delegate`.

- **`delegate-status next-action`** prints `watch`, `land`, `pick` or `idle` with its reasons. It is the zero-token gate: plain `gh` and `jq`, in Watch's order and then Pick.
- **`scripts/delegate-loop --agent claude|codex|opencode`** asks the gate, sleeps while idle, and otherwise starts the CLI once per pass with `prompts/delegate-run.md`, in a fresh context. It reads the project's `.claude/delegation.md`, and claims under a stable session name. It stops on a STOP file or after a run of failures, and caps agent passes per day. It logs each pass and its token use to `.delegate-loop/`.
