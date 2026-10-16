# review-pack fixture

`test/review-pack.sh` builds a git worktree from these files: `base/` is
committed, `staged/` is copied over it and staged, and `implementer.md` is the
implementer's report the pack carries. `docs/usage.md` holds a fenced code
block, so the pack must fence the diff with a longer run of backticks.

The test also unstages `docs/usage.md` to check that a diff with no backtick
still gets a pack fenced with three, commits the staged change to check
`--base`, and merges a conflicting branch it builds itself to check `--merge`.
