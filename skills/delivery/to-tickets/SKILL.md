---
name: to-tickets
description: Turn a sliced plan, a set of child stories, a spec or the current conversation into tracker tickets, one per vertical slice, each with acceptance criteria and the tickets that block it. Use when asked to create, file, raise or open issues or tickets for planned work, to put a plan on the tracker or backlog, or to make planned work ready for `/delegate`. Publishes nothing until the user approves the list.
---

# To Tickets

Turn planned work into **tickets**: one per vertical slice, each saying what it
delivers, how to tell it is done, and which tickets **block** it. A good ticket
can be picked up cold, by a person or by a delegated agent, without the
conversation that produced it.

This skill publishes; it does not slice. Slicing belongs to `story-splitting`
(what small stories exist) and `planning` (how one story is built). Based on
Matt Pocock's `to-tickets`; see `references/source-notes.md`.

## 1. Gather the source

Work from what is in the conversation. When the user names a source (a plan or
spec path, an issue number or URL), read all of it, including an issue's
comments.

Read the repository's instructions for its tracker, labels, issue templates and
domain glossary. Titles and bodies use the glossary's terms (load
`ubiquitous-language` if a new term appears) and respect the ADRs in the area.

## 2. Check the slices are slices

Each candidate ticket must be a narrow but complete path through every layer
it needs, demonstrable or verifiable on its own, and small enough for one pull
request of the project's usual size.

- **Already sliced** (a `planning` plan, `story-splitting` child stories): keep
  the source's slices, names and order. Do not re-slice someone's approved plan.
  Report a slice that looks horizontal or too large as a question in step 4.
- **Not sliced, or sliced by layer** (database, API, UI, tests as separate
  items): stop and load `story-splitting`, then come back.
- **Prefactoring** that makes a slice easier is its own ticket and blocks that
  slice. Make the change easy, then make the easy change.
- **A wide mechanical change** (rename a column, retype a shared symbol) cannot
  land green as one vertical slice. Sequence it as expand, then migrate in
  batches sized by blast radius, then contract: the expand ticket blocks every
  migrate batch, and every batch blocks the contract. `planning` covers this
  under its horizontal-work exceptions.

## 3. Look for tickets that already exist

Before drafting, search the tracker (open and recently closed) for each slice's
subject. For each match, decide: reuse it as it stands, update it, or create a
new ticket that links to it. Show the matches in step 4. Never create a second
ticket for work that already has one. If you could not search, say so in step 4.

## 4. Agree the list

Present a numbered list. For each ticket:

- **Title**: the observable outcome, in the glossary's words.
- **Delivers**: the end-to-end behaviour this ticket makes work, and for whom.
- **Blocked by**: the tickets that must finish first, or none. List only what
  genuinely gates it, not everything that comes earlier in the plan.
- **Who can do it**: `agent` or `human`. A step that needs a person's
  judgement, authorship or access (authoring evaluation data, a peer review, a
  written go/no-go decision) is `human`.
- **Existing**: any match from step 3 and what you propose to do with it.

Then ask, once: is the granularity right; is each blocking edge real; should
any tickets merge or split; and which labels and milestone apply. Iterate until
the user approves the list. Approval of a plan is not approval to publish it.

## 5. Publish

Publish only the approved list, to the tracker the repository declares.

**An issue tracker (GitHub, Linear, …).** Create one issue per ticket, blockers
first, so each later ticket cites real identifiers. Use the issue template
below. Record blocking edges with the tracker's native dependency where it has
one, and in the body as well. If the source was itself an issue, make each
ticket its sub-issue, and do not close or edit the parent.

**No tracker.** Write one file per ticket where the repository keeps such
files, or beside the plan as `tickets/<NN>-<slug>.md`, numbered from `01` in
dependency order. Never one combined file.

**Labels.** Apply only the labels the user approved in step 4. Never apply the
label that makes a ticket eligible for delegation (`agent-ready` by default):
the human who owns the backlog adds it, ticket by ticket. Never set a label
the delegator derives (`in-progress`, `blocked`, `needs-answer`,
`awaiting-review`).

**Link back.** When the source is a file in the repository, add each ticket's
identifier to its slice there, in the same change that the repository's
workflow uses for plan edits. The plan stays the place where the order lives.

Finish by reporting each ticket's identifier and title, the **frontier**
(tickets with no open blocker, which can start now), and anything not created
and why.

## Issue template

```markdown
## What to build

The end-to-end behaviour this ticket makes work, from the actor's point of
view: who does what, and what they then see. Not a layer-by-layer task list.

## Acceptance criteria

- [ ] Observable criterion 1
- [ ] Observable criterion 2

## Not in this ticket

- Anything a reader might assume is included and is not.

## Dependencies

- Blocked by #<n>: <its title>

## Source

<plan or spec path and slice heading, or the parent issue>
```

- `## Acceptance criteria` followed by a list, and `Blocked by #<n>` lines
  under `## Dependencies`, are the exact shapes `delegating-github-issues`
  reads. Keep both headings even when an issue template adds others. With no
  blockers, write `None: can start immediately`.
- A `human` ticket starts its body with `**Needs a human:** <why>`.
- Omit `## Not in this ticket` when there is nothing to exclude.
- Copy acceptance criteria from the source. Where the source has none, write
  them, mark them as drafted by you in step 4, and get them approved there.
- Leave out file paths, line numbers and code: they go stale before the ticket
  is picked up. The exception is a snippet that records a decision more
  exactly than prose can (a schema, a state machine, a type shape). Inline only
  the deciding part and say where it came from.
- Write bodies for a reader with no context; load `writing-for-agents` when it
  is installed.
