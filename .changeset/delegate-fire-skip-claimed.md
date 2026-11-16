---
"@conjurer-rich/skills": patch
---

`delegate-fire` no longer starts a session for a PR another session has claimed. Just before a `watch` or `land` fire, and before the finishing fire under `--reserve`, it re-reads each PR's live claim with the new read-only `delegate-status holder <n>` and leaves out the claimed ones, reporting `claimed (PR #N by <session>)`. A Ready click wakes the PR's own session at the same moment it starts the workflow, so the gate's first read could be stale, and the session it started could only see the claim and stop.
