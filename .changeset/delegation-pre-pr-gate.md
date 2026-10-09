---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: the `pre_pr_gate` default no longer points at a `/pr` command that craft does not ship. It is now the project's own pre-PR gate if it has one, else the `mutation-testing` skill's `references/pr-readiness.md`. The PR body's **Summary** also gains a short view of the change (pseudocode, a call tree, a file tree or a diff sketch) and a merge-danger line (one-way or two-way door, blast radius).
