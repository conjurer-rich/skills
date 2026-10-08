---
"@conjurer-rich/skills": minor
---

`engineering-practice` now carries the engineering guidelines itself instead of pointing at a copy of the old `CLAUDE.md`. Policy lives in its `SKILL.md`; which skill to load for which work lives in `references/routing.md`, merged from both old routing lists and limited to skills that are shipped or marked "when installed".

New `global/CLAUDE.md` (with `global/AGENTS.md` linked to it) and `scripts/install-global`, which links it to `~/.claude/CLAUDE.md` and, when Codex or OpenCode are installed, to their `AGENTS.md`. It backs up any existing file and retires the old `~/.claude/base-CLAUDE.md`. Run it once from a clone; `--copy` where symlinks are unavailable.
