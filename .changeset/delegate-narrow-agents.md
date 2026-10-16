---
"@conjurer-rich/skills": minor
---

delegating-github-issues: dispatches now use four narrow agent types shipped in `agents/` (`delegate-implementer`, `delegate-reviewer`, `delegate-walkthrough`, `delegate-mechanical`) instead of `general-purpose`. Each carries only the tools its role uses, so a subagent's first turn costs about half as many tokens; the reviewer has no edit tool and, by instruction, uses write only for its report. Where the types aren't installed, the skill falls back to `general-purpose` with the same brief and model.
