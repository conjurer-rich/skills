---
"@conjurer-rich/skills": patch
---

`scripts/install-global` now works from a clone without symlink support (Git Bash on Windows without developer mode). Codex's and OpenCode's `AGENTS.md` used to receive the single word `CLAUDE.md`, because such a clone checks the `global/AGENTS.md` symlink out as a plain file; every target now points at `global/CLAUDE.md` itself. A re-run also recognises the copy it fell back to as current, instead of backing it up and copying it again each time. `scripts/*` is now checked out with LF endings, so a Windows clone keeps the CR out of their shebangs, and `test/run.sh` gets further on Windows: `check-portability.py` reports paths with `/`, and the version-sync and eval checks pass paths to Node as arguments.
