---
"@conjurer-rich/skills": minor
---

delegating-github-issues: a PR the human marked Ready or answered is now finished whatever the lease holds. A Run that finds the lease `full` does a finish-only pass (Review, Land and Sync, never Pick or Work) instead of exiting, a session waiting on the human releases its lease slot, and `delegate-fire` fires for `watch` or `land` even when chains are live or the lease is full; only `pick` still needs a free slot. `max_open_prs` now counts the open PRs awaiting a first look: a delegated PR that is no longer a draft, or is titled `[blocked]`, is reported as `ready_prs` or `blocked_prs` and no longer stops new work.
