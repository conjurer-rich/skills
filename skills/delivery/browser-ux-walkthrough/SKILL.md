---
name: browser-ux-walkthrough
description: Walk a changed UI surface in a real browser against a project's own doctrine checklist, grade the checklist sections the change can affect, in both themes when styles or tokens changed, fix findings, and produce a findings table with screenshots for a PR body. Use when a PR or diff touches user-facing UI and the project has a stack skill with a Recipe and a Checklist, when asked to "walk through", "dogfood", or "UX-check" a change, or when the delegating-github-issues skill reaches its walkthrough step. It is a review that produces findings, never a new asserting test.
---

# Browser UX walkthrough

## Inputs

- **Stack skill**: a project skill with a `## Recipe` (boot, readiness, sign-in, session naming, theme switch) and a `## Checklist` (ids with one-line rules). Load it first. Without one, stop and say which project skill is missing.
- **Diff**: `git diff --cached --name-only` (or the PR's file list). Only user-visible UI files matter: test files (`*.test.*`, `*.spec.*`, `__tests__/**`) are not UI files. A diff with no user-visible UI file needs no walkthrough; say so and stop before booting anything.
- **Worktree path** and **session name** (use the worktree directory name).

## Procedure

1. **Boot.** Follow the Recipe. Boot once: the stack stays up until step 7. If readiness is not reached within 3 minutes, return `blocked: <last error line>` and stop; the caller files the follow-up.
2. **Sign in** per the Recipe and confirm its readiness check.
3. **Scope.** Grade only the Checklist sections the change can affect. Sort each changed UI file into a kind, take the widest scope any file needs, and record the sections skipped and why:

   | Changed files | Sections graded | Themes |
   |---|---|---|
   | Copy only (message catalogues, copy keys, static text) | every section except tokens and motion | one |
   | Markup (components, routes, layouts) with no style change | every section except tokens | one |
   | Style or token (stylesheets, design tokens, theme files, or a markup change to class names or style values) | every section | both |

   Sections are the Checklist's own headings (for example purpose, copy, tokens, focus, motion, layout). A heading the table does not name is graded. If the stack skill has a `## Checklist scope` section, its mapping wins over this table. If the stack skill has a *Themes* rule (a `## Themes` section, or a Themes line in its Recipe), that rule picks the themes and this table's Themes column does not apply. Without one: Both themes only when the scope is **Style or token**; otherwise grade one theme, the Recipe's default (light when it names none), and say which.
4. **Map the surface.** From the diff, list the routes and components touched: route files give paths; components give the pages that import them (`grep -rl "<ComponentName>" <ui root> --include=*.tsx`); copy files give every page that renders the copy key. Produce a list of `(surface name, URL, how to reach it)`.
5. **Walk.** For each surface, in the first theme: `agent-browser --session <s> open <url>`, `agent-browser --session <s> snapshot -i`, perform the interaction the issue describes, and grade every Checklist item in the scoped sections **pass**, **finding** or **n/a** with a one-line reason. Take `agent-browser --session <s> screenshot <dir>/<surface>-<theme>-before.png`. When the scope takes both themes, switch theme per the Recipe, reload, and repeat for the second.
6. **Fix.** For each `finding`, make the change in the worktree, under the same TDD rule the project applies to UI (a failing behaviour test first where the finding is behaviour; token, copy or layout findings that the project's guards already pin need no new test). Re-walk only the surfaces affected, in the themes graded, and take `-after.png` shots. Repeat until no `finding` remains or each remaining one is **deferred** with a `follow-up` issue number. A caller that must not write production code, such as `delegating-github-issues`, skips this step. It leaves the stack running, hands the findings to its implementer, then re-walks the affected surfaces on the running stack for the `-after.png` shots. Restart a server per the Recipe only when it does not reload changed files.
7. **Stop the stack once**, per the Recipe: after the `-after.png` shots, or after grading when there are no findings.
8. **Return** the section below and the screenshot paths.

## Output

```markdown
## UX walkthrough

Surfaces: <n>. Items graded: <scoped item count> × <1 or 2> themes (<theme or "light and dark">). Findings: <f> (fixed <x>, deferred <d>).
Sections skipped: <sections and why, e.g. "tokens, motion: copy-only change">, or "none".

| Item | Surface | Theme | Grade | Reason | Fix |
|---|---|---|---|---|---|
| T2 | Workspace home | dark | finding → fixed | accent button text used `--text-primary` | `<short sha>` |
| P2 | Workspace home | light | pass | one primary action: "Open canvas" | |
| L5 | Canvas | both | n/a | canvas owns its own scroll by design | |

Screenshots: `<evidence path>/<surface>-light-before.png` · … (before/after per surface per theme)
```

Rows: every `finding` (fixed or deferred) and every `n/a`; `pass` rows may be summarised as "all other items pass" per surface and theme to keep the table readable. Deferred rows cite the follow-up issue in the Fix column.

## Rules

- Grade against the Checklist ids only; do not invent items. Skip a section only through **Scope**, and name it in the output. If the doctrine seems wrong, that is a finding against the checklist, filed as an issue, not a silent skip.
- Never write a screenshot or pixel assertion into the test suite. This is a review.
- Never point the session at a deployed URL; the Recipe's local stack only.
- One session per worktree; never reuse a session across worktrees.
- If `agent-browser` cannot reach an element through the accessibility tree (canvas-rendered content), say so in the row's reason and grade what is reachable; do not fall back to coordinates without saying so.
