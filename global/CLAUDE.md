# Global instructions

Before any coding task, load the `engineering-practice` skill
(`craft:engineering-practice` in Claude Code). It holds the engineering
guidelines and the routing table for every other skill; this file does not
repeat them. A repository's own `CLAUDE.md` / `AGENTS.md` overrides both.

## Personal preferences

- **Visual companion: always allowed.** When a design or brainstorming
  workflow could use the browser-based visual companion for mockups, diagrams
  or layout comparisons, use it whenever it would help. Do not ask for consent
  each time.
- **Skills live in the craft plugin.** A project vendors a skill into its own
  `.claude/skills/` only when that skill is genuinely specific to the project;
  general-purpose skills are never copied into a repository.
