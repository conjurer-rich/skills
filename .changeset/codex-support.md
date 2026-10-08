---
"@conjurer-rich/skills": minor
---

Codex support. Install with `codex plugin marketplace add conjurer-rich/skills` then `codex plugin add craft@conjurer`; Codex reads the same `.claude-plugin/` manifests.

- Every skill has an `agents/openai.yaml`. User-invoked skills and the Claude Code-only ones (`delegating-github-issues`, `browser-ux-walkthrough`) turn off Codex's implicit invocation.
- `/plan` and `/continue` are now user-invoked skills, `plan` and `continue`, so they work in both harnesses. `/delegate` stays a Claude Code command.
- The `tdd-guardian` and `refactor-scan` agents are now skills of the same name. In Claude Code they run in a forked subagent (`context: fork`); elsewhere they run inline. The delegator uses a project's own `tdd-guardian` agent when it has one, and the skill otherwise.
- Each item has a portability tier (portable, degrades, claude-only) in `portability.json`. `craft:ask` marks the items that do not run, or run differently, in Codex.
- New checks: `scripts/check-portability.py` keeps portable skills free of Claude Code tool names and `~/.claude` paths, and `scripts/check-codex-install.py` installs craft into a throwaway Codex home in CI and checks which skills the model is offered.
