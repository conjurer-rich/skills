---
"@conjurer-rich/skills": patch
---

Upstream watch (mattpocock/skills, to `4ae2317d`). `review`, `grilling` and `improve-codebase-architecture` now start their subagents or explorers with a fresh context window instead of a fork of the session. `expectations` gains rules for learnings filed where they cannot track the code: date each entry, pin code claims to a `repo@commit`, and supersede rather than rewrite.
