---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: issues whose blockers form a loop are now named as a cycle. `delegate-status status` gives each member a `cycle` field and lists each loop once under `cycles`, and `next-action` carries them, with an idle reason telling the human to remove one of the links. The members stay `blocked`, so labels and tickets behave as before. Previously Pick reported them as plain `blocked` on every pass, with nothing to say they could never free themselves.
