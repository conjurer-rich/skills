---
name: engineering-practice
description: Core engineering practice — TDD is non-negotiable, behaviour-driven testing, TypeScript strict, functional preferences, small incremental changes, and the routing table for every other skill in this plugin. Load this first in any coding task; it is the context that ~/.claude/CLAUDE.md supplies on a local machine and that a plugin install does not load automatically.
---

# Engineering practice

A plugin's files are not loaded as project context, so on any machine that
gets these skills via the plugin — a cloud dev container, a fresh checkout, a
teammate's laptop — the engineering guidelines arrive through this skill.

Read the full document now: [`references/guidelines.md`](references/guidelines.md),
in this skill's folder.

It is ~205 lines and is the single source of truth: this skill deliberately
does not restate it, so the two cannot drift.

## What it covers

- **Core philosophy** — TDD for new or changed behaviour; refactoring and
  mechanism reduction start from passing preservation evidence.
- **Quick reference** — key principles, preferred tools, the definition of a
  "phase of work" for the mutation gate (one PR review boundary).
- **Skill routing** — which of this plugin's skills to load for which kind of
  work.

## After reading

Follow its routing table rather than guessing: it names the skill for
specification, planning, TDD, testing, refactoring, architecture, front-end
work, and review. Repository-specific `CLAUDE.md` files override it where they
disagree.
