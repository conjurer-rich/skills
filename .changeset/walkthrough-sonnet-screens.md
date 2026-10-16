---
"@conjurer-rich/skills": minor
---

delegating-github-issues: the UX walkthrough now runs on a new `walkthrough_model` parameter (default `sonnet`) instead of the session's model. browser-ux-walkthrough walks each screen in one shell call, with the snapshot and screenshot written to files rather than printed, and keeps screenshots at most 1024 px wide (a 1024 px viewport at device scale 1, or a downscale when an image tool is present) before reading them.
