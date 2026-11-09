---
"@conjurer-rich/skills": patch
---

delegating-github-issues: `delegate-status lease take` now deletes every chain-slot claim on the lease tracking issue that has gone twice `claim_ttl` without a heartbeat, so dead and lost chains no longer leave their claims behind for good. REST lists are paged by hand instead of with `gh api --paginate`, whose `/repositories/<id>/` Link URLs the Claude Code on the web proxy refuses, so a list longer than 100 items no longer fails.
