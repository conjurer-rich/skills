---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: Pick now classifies an issue `blocked` while an issue or PR it depends on is still open. Blockers come from GitHub's native "blocked by" dependencies, a `## Dependencies` section, or `Blocked by #N` lines. Pick skips a blocked issue, and the issue frees itself once every blocker closes or merges. `status --sync-labels` keeps two derived labels in step with the classification: `needs-answer` (`--answer-label`) while the delegator waits on the human, and `blocked` (`--blocked-label`) while an issue is blocked. Both are recomputed every pass and never read as state.
