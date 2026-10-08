---
name: ask
description: Ask which craft skill, agent, command or flow fits your situation, including shelved skills worth promoting. A router over everything in craft. User-invoked.
disable-model-invocation: true
---

# Ask

You don't remember every skill, so ask. Describe the situation; this map names
the skill or the path through several.

Before stating what a skill does or recommending a step be skipped, read that
skill's `SKILL.md`: the summaries here are for orientation only. In Claude Code
every name below is `craft:<name>`; in Codex it is `$<name>`.

**Harness notes.** Items marked *(Claude Code)* rely on Claude Code tools and do
not run elsewhere. Items marked *(subagents)* run their parts in parallel
where the harness has subagents, and one after another where it does not.

A **flow** is a path through the skills. Most work travels the main flow; the
on-ramps join it; everything else is standalone or a vocabulary layer
underneath.

## The main flow: idea → ship

1. **Sharpen the idea.** `grill-me`, when installed, interviews you
   relentlessly. With a repository to write into, follow it with
   `specification` to turn the conversation into acceptance criteria, and
   `ubiquitous-language` for any new or changed term. Visual work with several
   screens: `storyboard` puts every mock on one reviewable page first.
2. **Tighten what you wrote.** `find-gaps` interrogates an existing spec, story
   or plan one question at a time and writes each answer back.
3. **Make it small.** `story-splitting` cuts an epic or feature into thin,
   end-to-end child stories. Do this before planning, never after.
4. **Plan.** `planning` turns one child story into small, known-good
   increments (`/plan` starts it). When one slice is too big to review, add
   `stack-pull-requests`; `/continue` advances the stack after a merge.
5. **Build.** `tdd` drives every behaviour change, with `testing` for the
   test design and `refactoring` after each green. `typescript-strict` and
   `functional` apply to every line. The `tdd-guardian` agent checks the
   process; the `refactor-scan` agent judges whether a refactor earns its
   place.
   - **Hand it off instead:** label the issue and run `/delegate` (the
     `delegating-github-issues` skill) to take it from issue to reviewable PR
     in its own worktree, with `browser-ux-walkthrough` for UI changes.
     *(Claude Code)*
6. **Check it before the PR.** `mutation-testing` runs once, at PR
   readiness; its `references/pr-readiness.md` is the evidence gate.
   `acceptance-review` checks every acceptance criterion against the
   evidence *(subagents)*. For bugs in the diff, use the harness's own
   reviewer (`/code-review` in Claude Code, `/review` in Codex). For high
   stakes, `double-check` gets an independent second opinion, preferably from
   another provider *(subagents)*.
7. **Close the loop.** `retro` looks back over the session and suggests
   changes to the environment: checks, standards, navigation pointers, and
   skills you could have used but didn't *(subagents)*. Run it in the session
   it reviews.

## On-ramps

- **Something's broken.** `debugging` for a local or runtime failure;
  `ci-debugging` when the pipeline is red. Both refuse to guess: evidence
  first, one hypothesis at a time. Then `retro` asks what would have
  prevented it.
- **Legacy code with no tests.** `characterisation-tests` pins what the code
  does today; `finding-seams` makes it testable without editing every caller.
  Then join the main flow at step 5.
- **A spare afternoon for upkeep.** `improve-codebase-architecture` surveys the
  codebase and ranks improvement candidates *(subagents)*; pick one and design
  it with `codebase-design`. `reduce-system-complexity` removes mechanism from
  a chosen path without changing behaviour.
- **About to deploy a service.** `twelve-factor` for the design; run the
  `twelve-factor-audit` agent before the first production deploy or when it
  works in one environment but not another. `observability` when you cannot
  tell what production is doing.
- **About to add a dependency or build something generic.**
  `evaluate-existing-solutions` checks what already exists first.

## By area

| Area | Skills |
| --- | --- |
| The rules every task follows | `engineering-practice` (load first; its `references/routing.md` is the model-facing version of this map) |
| Testing | `tdd`, `testing`, `test-design-reviewer`, `mutation-testing`, `front-end-testing`, `react-testing` |
| Code | `typescript-strict`, `functional`, `refactoring`, `reduce-system-complexity` |
| Front end | `xstate` (before reaching for `useState`), `react-performance`, `browser-ux-walkthrough` |
| Architecture | `codebase-design`, `structure-codebase`, `improve-codebase-architecture`, `hexagonal-architecture`, `domain-driven-design`, `event-sourcing` |
| Services and APIs | `api-design`, `bff-entry-points`, `secure-oauth-oidc`, `twelve-factor`, `observability` |
| Writing and knowledge | `technical-writing`, `diagrams`, `ubiquitous-language`, `expectations` (where a learning should live), the `adr` agent (record a decision), the `learn` agent (capture a lesson) |
| When an answer didn't land | `/wtf` re-explains the last answer in plain UK English |
| Finding more skills | `find-skills`, when a kind of task keeps coming up with no skill behind it, or `retro` reports one missing |

## Phase boundaries

At the boundary between two phases (grilling → planning → building → review),
choose deliberately:

- **Continue** when what you have in context is what the next phase needs.
- **Clear** when nothing here matters to what comes next.
- **Hand off** to a subagent or a fresh session for a tightly scoped side task,
  and take back only its report.
- **Compact** when you must keep going but the context is getting long; do it
  at a boundary, not mid-phase.

Keep sharpening, splitting and planning in one unbroken context so each step
builds on the last; start each build from the plan.

## On the shelf

These are kept in the repository but not installed, so they cost nothing in
every session. When one fits, say so and offer to promote it: move its folder
from `shelf/` into the plugin and list it in `.claude-plugin/plugin.json`.

| Shelved item | Reach for it when… |
| --- | --- |
| `production-parity-skill-builder` | the first time a bug shows up only in production; it builds a per-app parity skill once |
| `bff-design` | deciding whether to add a backend-for-frontend, or splitting one |
| `cli-design` | building a command-line tool (CC BY-SA 4.0) |
| `render-code-shape` | you want a cited map of existing code's modules and types before changing it |
| `panel-review` with `graph-engineering` | a large structural change needs review through several craft skills at once *(Claude Code)* |
| `teach-me` | learning a new topic over several sessions (to be replaced by `teach`) |
| `docs-guardian`, `progress-guardian`, `ts-enforcer`, `use-case-data-patterns` agents | documentation upkeep, long-running plan tracking, a TypeScript-only review, or tracing a use case through the code |
| `/setup` | onboarding a new project's `CLAUDE.md`, hooks and commands in one go |
