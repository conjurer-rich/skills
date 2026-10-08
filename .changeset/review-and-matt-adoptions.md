---
"@conjurer-rich/skills": minor
---

New skills adapted from Matt Pocock's `mattpocock/skills@b0618bc4` (MIT):

- `review`: reviews a branch, PR or work in progress against a fixed point on two separate axes. **Standards** covers the repository's written standards, up to three craft skills chosen from the diff, and Fowler's smell baseline. **Spec** runs `acceptance-review` against the originating issue. Bugs stay with the harness's own reviewer (`/code-review`, `codex review`). `tdd-guardian` and `refactor-scan` now point at it for whole-PR review.
- `grilling` (model-invoked), with the user-invoked entry points `/grill-me` (writes nothing) and `/grill-with-docs` (records settled terms through `ubiquitous-language` and decisions through the `adr` agent). Skills that used to say "`grill-me` when installed" now load `grilling`.
- `writing-for-agents`: the guide for writing skills and `CLAUDE.md` / `AGENTS.md`; `retro` now always loads it.
- `teach`: learn a topic over several sessions in a workspace in the current directory. It **replaces `teach-me`**, which is removed from the shelf.
