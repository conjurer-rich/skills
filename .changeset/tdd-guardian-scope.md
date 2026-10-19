---
"@conjurer-rich/skills": patch
---

`tdd-guardian` no longer forks when a subagent loads it, so a delegator's Process check reviews the pack it was briefed with instead of a PR it guessed. With no scope given, the skill asks or names the scope it chose on the first line of its report. The delegator's Process-check briefs now tell the reviewer to apply the checklist in its own context.
