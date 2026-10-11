---
"@conjurer-rich/skills": patch
---

delegating-github-issues: the implementer brief now says to read each file once, run filtered quiet tests with output sent to a file, and wait on long runs as background tasks instead of a polling or sleep loop. The repair round dispatches a fresh implementer with a findings brief rather than messaging the first one. Subagents return `blocked` when the stack a full-suite run needs is not up.
