---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: when you start a Work yourself and the issue needs a chain of dependent decisions (or asks "grill me"), the delegator now runs `grilling` with you in the chat, then posts the decisions and derived criteria on the issue for your 👍. An unattended Work still asks on the issue, but a question comment now carries a whole round: every independent question, each with a recommended answer you can accept with "yes". Once you 👍 derived criteria, the new `delegate-status promote-criteria` appends them to the issue body under `## Acceptance criteria`, so they sit at the top of the issue; your text and the comment are kept.
