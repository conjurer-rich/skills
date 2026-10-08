---
name: review
description: Review a branch, pull request or work in progress against a fixed point on two separate axes — Standards (does the diff follow the repository's written standards and the craft skills that apply to it?) and Spec (does it do what the originating issue or spec asked, no more and no less?). Use when reviewing a branch or PR, before opening a PR, or when asked to "review since <ref>". Bugs are left to the harness's own reviewer.
---

# Review

Two-axis review of the diff between `HEAD` and a fixed point:

- **Standards**: does the code follow this repository's written standards, and
  the craft skills that govern the kind of code it is?
- **Spec**: does the code do what the originating issue or spec asked?

The axes are reviewed separately and reported side by side, never merged, so a
pass on one cannot hide a failure on the other.

**Not this skill:** finding correctness bugs. Use the harness's own reviewer
for that (`/code-review` in Claude Code, `/review` or `codex review` in Codex)
and run both when a change matters.

## 1. Pin the fixed point

Use the ref the user names (a commit, branch, tag, `main`, `HEAD~5`). With no
ref, use the merge-base with the default branch. A pull request number means
its base branch.

Capture the diff once: `git diff <fixed-point>...HEAD` (three dots, so the
comparison is against the merge-base), plus `git log <fixed-point>..HEAD
--oneline`. Include uncommitted changes when the user asks to review work in
progress, and say that you did.

Confirm the ref resolves (`git rev-parse <fixed-point>`) and the diff is not
empty before going further. A bad ref or an empty diff stops the review here.

## 2. Find the spec

In this order:

1. Issue references in the commit messages or branch name (`#123`,
   `Closes #45`), fetched from the repository's tracker.
2. A path the user passed.
3. A spec or plan file under `docs/`, `specs/`, `plans/` or `.scratch/` that
   matches the branch or feature.
4. Otherwise, ask where the spec is. If there is none, the Spec axis is
   skipped and the report says "no spec available".

## 3. Gather the standards

- **The repository's written standards.** Every file that says how code
  should be written: `CLAUDE.md` / `AGENTS.md` at every level the diff
  touches, `CODING_STANDARDS.md`, `CONTRIBUTING.md`, and docs those files
  point to. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it is on
  the list.
- **Up to three craft skills, chosen from the diff's traits.** For example:
  `typescript-strict` for TypeScript, `testing` (and `front-end-testing` or
  `react-testing`) when tests changed, `functional` for data transformations,
  `hexagonal-architecture` or `domain-driven-design` only when the repository
  has opted in, `api-design` for an externally consumed contract,
  `structure-codebase` when files moved. Name the three you chose and why.
- **The smell baseline** below, which applies even when the repository
  documents nothing.

Two rules bind the baseline: **the repository overrides it** (where a written
standard endorses something the baseline would flag, drop the smell), and
**each smell is a judgement call**, labelled as "possible Feature Envy", never
a hard violation. Skip anything tooling already enforces.

Fowler's code smells (*Refactoring*, chapter 3), each as *what it is* → *how to
fix*:

- **Mysterious Name**: a name that does not reveal what it does or holds →
  rename it; if no honest name comes, the design is murky.
- **Duplicated Code**: the same logic shape in more than one hunk or file →
  extract the shared shape.
- **Feature Envy**: a function reaching into another object's data more than
  its own → move it to the data it envies.
- **Data Clumps**: the same few fields or parameters travelling together →
  give them one type.
- **Primitive Obsession**: a primitive standing in for a domain concept → give
  the concept its own small type.
- **Repeated Switches**: the same `switch` or `if` cascade on the same type in
  several places → one polymorphic call or one shared map.
- **Shotgun Surgery**: one logical change forcing scattered edits → gather what
  changes together.
- **Divergent Change**: one module edited for several unrelated reasons →
  split it.
- **Speculative Generality**: abstraction or parameters for needs the spec
  does not have → inline it until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation → hide the walk behind
  one method.
- **Middle Man**: a module that mostly delegates → call the real target.
- **Refused Bequest**: an implementer ignoring most of what it inherits →
  composition instead of inheritance.

## 4. Review both axes

Run each axis in its own subagent, in parallel, so neither pollutes the other's
context; where the harness has no subagents, run Standards and then Spec, and
do not let the first colour the second. Each subagent receives the diff
command and commit list.

- **Standards** also receives the list of standard files, the chosen craft
  skills (it loads them), and the smell baseline pasted in full. Brief:
  "Report, per file or hunk, (a) every place the diff breaks a written
  standard or a loaded skill's rule, citing the file and rule; (b) any
  baseline smell, named and quoted. Mark written-standard breaches as hard
  violations where they are; smells are always judgement calls. Skip what
  tooling enforces. Under 400 words."
- **Spec** loads `acceptance-review` and runs it against the spec, with the
  diff as the implementation under review. Brief: "Report (a) criteria
  missing or partly met, (b) behaviour in the diff nobody asked for, (c)
  criteria that look met but whose implementation looks wrong. Quote the spec
  for each. Under 400 words."

## 5. Report

Present the two reports under `## Standards` and `## Spec`, verbatim or
lightly cleaned. Do not merge or re-rank findings across axes.

End with one line per axis: the number of findings and the worst one within
that axis. Do not pick a single winner across axes.
