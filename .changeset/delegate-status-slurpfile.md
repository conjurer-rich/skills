---
"@conjurer-rich/skills": patch
---

delegate-status passes comments, threads, reviews and timelines to jq through files (`--slurpfile`), so a PR or issue with more than 128 KB of comments no longer fails with "Argument list too long".
