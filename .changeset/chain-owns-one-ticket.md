---
"@conjurer-rich/skills": minor
---

delegating-github-issues: a delegator chain now owns one ticket until it is complete, by default. The ticket (issue and PR numbers) is kept as `ticket` in `run-state.json` and carried to the session a hand-off creates, which resumes it. While the ticket is open the chain never runs Pick, runs Review, Sync and Land only on its own PR and subscribes only to that PR; once the PR merges or closes, or the human releases the ticket by removing the eligibility label from its issue, the next pass picks as before. A chain about to wait on the human or on CI hands off first, and the waiting session schedules no wakeup: an event on the ticket wakes it. Parallelism comes only from `max_chains`. This changes the default behaviour of `/loop /delegate`; there is no opt-out.
