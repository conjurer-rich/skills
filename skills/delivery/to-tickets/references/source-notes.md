# to-tickets: source notes

This skill is an attributed adaptation of Matt Pocock's `to-tickets`.

## Source

- Repository: <https://github.com/mattpocock/skills>
- Pinned revision: [`abeeaf95`](https://github.com/mattpocock/skills/tree/abeeaf95660ba9e8b7c753eb38f441ca707a8823)
- File:
  [`skills/engineering/to-tickets/SKILL.md`](https://github.com/mattpocock/skills/blob/abeeaf95660ba9e8b7c753eb38f441ca707a8823/skills/engineering/to-tickets/SKILL.md)
- Licence: MIT, Copyright (c) 2026 Matt Pocock. The full notice is in
  [`../LICENSE`](../LICENSE).

## Taken

- One ticket per tracer-bullet vertical slice, each declaring the tickets that
  block it, published blockers first so edges cite real identifiers.
- The steps: gather the source, draft, agree a numbered list with the user,
  then publish.
- Prefactoring as its own first ticket; expand, migrate, contract for a wide
  mechanical change.
- Native blocking relationships where the tracker has them; sub-issues when the
  source was an issue; never close or edit the parent; the frontier.
- One file per ticket when there is no tracker.
- No file paths or code in a ticket, except a snippet that records a decision.
- The "What to build", "Acceptance criteria" and blocked-by sections of the
  issue template.

## Changed (Richard Allen, 2026-11-21)

- The skill publishes and does not slice: an already sliced plan keeps its
  slices, and unsliced input goes to `story-splitting` first. Upstream drafts
  the slices itself.
- Added a search for existing tickets before drafting.
- A slice is sized to one pull request of the project's usual size, not to one
  context window.
- Each ticket says whether an agent or a human can do it.
- The template uses the headings `delegating-github-issues` reads
  (`## Acceptance criteria`, `Blocked by #<n>` under `## Dependencies`), and
  adds "Not in this ticket" and "Source".
- The delegation label is never applied; upstream applies `ready-for-agent` by
  default. craft's delegator may not label issues, and the human who owns the
  backlog decides eligibility.
- The tracker and labels come from the repository's instructions, not from a
  setup skill.
- Model-invocable, with publishing gated on the user's approval of the list.
  Upstream is user-invoked only.
- Tickets link back into the source plan.
