---
"@conjurer-rich/skills": minor
---

delegating-github-issues: a `[blocked]` PR, and a failed repair round under Watch or Land, now writes each remaining blocking finding as **Fix options**: numbered options (`1a`, `1b`, …) with a one-line trade-off and one marked **(recommended)**, or `single fix:` when only one fix makes sense, plus a `defer to a follow-up issue` option where deferral is allowed (never for unmet acceptance criteria or `tdd-guardian` findings). The list ends with a ready-to-paste suggested reply such as `1a, 2, 3 defer`. Review treats a reply naming option ids, or "fix all" when every finding is a single fix, as actionable, and copies the chosen options verbatim into the implementer brief.
