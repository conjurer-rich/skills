---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: `--sync-labels` now puts `needs-answer` and `blocked` on issues another chain holds as its ticket, by the same rules as any other issue. Only an issue under another session's live claim is left alone. A ticketed issue's status keeps its `reason`, `criteria` and `blocked_by` beside its holder. Previously an issue whose chain was waiting on the human carried neither `in-progress` nor `needs-answer`, so it looked like nobody's work.
