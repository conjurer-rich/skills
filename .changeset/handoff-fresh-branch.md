---
"@conjurer-rich/skills": patch
---

delegating-github-issues: the hand-off names a fresh `claude/delegate-handoff-<8 hex>` outcome branch that is absent from `origin`, so the cloud harness's stop hook no longer reports default-branch commits as unpushed and loops. A new optional `environment_id` parameter (default none) is passed to the hand-off session when set.
