---
"@conjurer-rich/skills": patch
---

`scripts/install-global` now works from a clone without symlink support (Git Bash on Windows without developer mode). Codex's and OpenCode's `AGENTS.md` used to receive the single word `CLAUDE.md`, because such a clone checks the `global/AGENTS.md` symlink out as a plain file. Every target now comes from `global/CLAUDE.md`, and `global/AGENTS.md` is gone. The script checks once whether symlinks work and copies when they do not, so a re-run reports those copies as current instead of backing them up and copying them again; where symlinks work, a copy left by `--copy` is still replaced by a link. `scripts/*` is now checked out with LF endings, so a Windows clone keeps the CR out of their shebangs, and `test/run.sh` gets further on Windows: `check-portability.py` reports paths with `/`, the version-sync and eval checks pass paths to Node as arguments, and `upstream-changes` prints UTF-8.
