---
"@conjurer-rich/skills": patch
---

delegating-github-issues: a new reference page, `references/cloud-environment.md`, says how to build a cloud environment the delegator works well in: only the GitHub connector, network access to `api.github.com`, a copy-paste setup script that checks `gh`, `jq`, `git` and `python3` and enables `pnpm` only when it is missing, and a GitHub access check with `gh api repos/<owner>/<repo>` rather than `gh auth status`. `references/session.md` links to it.
