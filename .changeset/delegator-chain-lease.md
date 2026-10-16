---
"@conjurer-rich/skills": minor
---

delegating-github-issues: a Run now takes one of `max_chains` chain slots (new parameter, default 1) before anything else, and exits at once with a one-line report when every slot is held by a live chain, so only the intended number of delegator chains run per repository. A new `delegate-status lease` subcommand takes, renews, heartbeats, releases and hands over the slots as claims on a tracking issue labelled `delegator-lease`; a hand-off passes the slot to the session it creates, so no third session can take it in between.
