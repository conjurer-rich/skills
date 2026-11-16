---
"@conjurer-rich/skills": minor
---

`delegate-fire` can now fill every free chain slot in one run. With a new optional `reserve-token` secret (a fine-grained token that writes issues as the delegator's login), the gate takes a lease slot and sets the ticket for each eligible issue in the name of a new session, then starts that session with a hand-off line. Sessions started together never compete for one issue, and an emptied lease refills in one run instead of one slot per run. One more session starts to finish any PRs that no session is working on. `delegate-status next-action` gains `--picks <n>`, which lists the issues and PRs to start sessions for, and a new `weekdays_only` setting stops the gate firing on weekends. The caller example now also runs on issue and PR events and every 15 minutes, and the reusable workflow skips events the delegator caused itself. Without the reserve token, behaviour is unchanged.
