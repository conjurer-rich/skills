---
"@conjurer-rich/skills": minor
---

Add the `delete-comment` skill. It classes every comment under a path as Tautology, Stale, Excuse or Decision Record. Tautology and Stale comments are deleted. Each Excuse is deleted and filed as an issue. Each Decision Record moves into an ADR. The skill then tightens the project's comment ratchet. `references/comment-ratchet.md` describes how to build a ratchet where none exists.
