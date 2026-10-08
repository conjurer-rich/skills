---
"@conjurer-rich/skills": minor
---

delegating-github-issues: run outside Claude Code (Phase 7b).

- **`references/harness.md`** names each Claude Code capability the skill uses, and what to do without it:
  - **Subagents:** in another harness, a headless `codex exec` or `claude -p` per brief, or the brief carried out in order.
  - **Models** and **reviewers:** set by parameters (below).
  - **Scheduling, PR subscriptions, session titles and Hand-off:** skipped outside Claude Code and under `delegate-loop`.
- **New parameters:**
  - `review_model` (default `opus`) and `mechanical_model` (default `haiku`) replace the pinned models.
  - `correctness_review` (default `/code-review` at medium effort; `codex review` in Codex) and `simplify` (default `/simplify`) replace the named built-ins.
- **`/delegate` is now a user-invoked skill,** `delegate`. In Claude Code it works as before: its context lines are still filled in before it loads. In another harness it says how to gather that context itself, and points to `scripts/delegate-loop`.
