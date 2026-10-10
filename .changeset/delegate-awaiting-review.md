---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: delegated PRs now show when they are waiting on you. `status --sync-labels` keeps a derived `awaiting-review` label (`--review-label`) on each delegated PR that no session is working on, has nothing left to answer, and whose current head you have not approved, and takes it off as soon as you comment. After each Review round, the new `delegate-status review-status` writes one line at the top of the PR body: the round, how many comments it addressed, the head commit and a link to the changes since your last review. GitHub never notifies you of work done through your own login, so these replace hunting through comments.
