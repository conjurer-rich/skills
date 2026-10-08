---
"@conjurer-rich/skills": minor
---

delegating-github-issues: cut the token cost of delegated runs, and hand off every run at its limit (ported from the `.dotfiles` fork, PRs 44 and 48).

- **Tiers and verification scope** come from the project's delegation file: `tier_small_max_lines`, `tier_small_max_packages`, `risk_paths`, the new `full_suite_paths`, and a **Verification scope** section, which replaces the `/pr` gate's complete-suite rule. Tier S writes no plan document and gets one self-review. The rules live in the new `references/tiers.md`. The expected tier also picks the implementer's model (`implementer_model_small` / `implementer_model_large`), with one escalation as before.
- **Short sessions.** The Stop rule hands off at 50 % context, 80 tool calls, or once the session's one issue has a PR, under `/loop` or not, and links the new session. A hand-off leaves a `<!-- delegator:handoff -->` PR comment; `delegate-status pr` returns it as `handoff`. See `references/handoff.md`.
- **Lean subagents.** Commit, push, PR creation and the CI wait run inline, with output in a log file. Every subagent gets a self-contained brief. Mechanical steps run on `model: haiku`.
- **Cheap Watch.** `delegate-status watch-digest` lets `/delegate` end an unchanged pass before loading the skill; the interval backs off from 10 to 60 minutes.
- **Claims.** `claim` refuses with exit 4 when another session holds a live claim. A background `heartbeat` keeps a claim live, and `claim_ttl` drops to 45 minutes.
- **CI.** `checks <pr> --head <sha>` waits on that exact commit; `--table` prints failing jobs' annotations and log tails.
- **Preflight.** A `preflight:` line lists the project's drift fixers, run before a PR's first push.
- **Measure.** Each delegated PR body ends with a `Delegation cost:` line; `delegate-status cost` sums it.
