---
"@conjurer-rich/skills": patch
---

The reusable `delegate-fire` workflow no longer skips events the delegator's login caused unless the new `skip-own-events` input is on. A delegator that posts as the human, through the human's `gh` auth, shares that login, so the filter skipped the human's own labels, Ready clicks and reviews, and only PR closes and the cron woke the gate.
