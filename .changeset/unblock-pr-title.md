---
"@conjurer-rich/skills": patch
---

delegating-github-issues: a PR the **Blocked** step opened no longer keeps its `[blocked]` title after it is unblocked. `delegate-status review-status` takes the prefix off in the same write as the status line, since a Review round only reaches it once the gate passed with no blocking finding left, and reports `unblocked: true` when it did. `delegate-status merge` drops the prefix from the squash subject and the merged PR, so it never reaches the default branch. Before this, nothing renamed the PR: merged and ready-for-review PRs still read `[blocked]`, while the derived labels said the opposite.
