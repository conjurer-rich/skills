---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: a ticket marker that no delegator session ever claimed the issue under (an orphan, typically reserved by `delegate-fire` for a session that never started) now lapses after `claim_ttl` instead of holding the issue for the 12-hour `ticket_ttl`. The longer lifetime applies once a claim on the issue shows the chain worked it. Status names such an issue's lapsed marker as `lapsed_ticket`, and Pick reads the issue as `free`.
