# Ask: source notes

This skill is an attributed adaptation of Matt Pocock's `ask-matt`, not a
copy.

## Source

- Repository: <https://github.com/mattpocock/skills>
- Pinned revision: [`b0618bc4`](https://github.com/mattpocock/skills/tree/b0618bc436ad893b3c5e84e55fba86586d34a404)
- Files:
  [`skills/engineering/ask-matt/SKILL.md`](https://github.com/mattpocock/skills/blob/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/ask-matt/SKILL.md),
  [`PHASE-BOUNDARIES.md`](https://github.com/mattpocock/skills/blob/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/ask-matt/PHASE-BOUNDARIES.md),
  [`agents/openai.yaml`](https://github.com/mattpocock/skills/blob/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/ask-matt/agents/openai.yaml)
- Licence: MIT, Copyright (c) 2026 Matt Pocock. The full notice is in
  [`../LICENSE`](../LICENSE).

## Taken

- A user-invoked router over the skills, organised as **flows** (a main flow
  plus on-ramps, standalone skills and a vocabulary layer) rather than as a
  list.
- "Read the skill before describing it or recommending a step be skipped."
- The phase-boundary choices (continue, clear, hand off, compact), condensed.

## Changed (Richard Allen, 2026-10-08)

- Rewritten for craft's skills, agents and commands; none of Matt's skill
  names survive except where craft has the same skill.
- The main flow follows craft's delivery path: grill and specify, find gaps,
  split stories, plan, build with TDD or hand off to `/delegate`, the
  mutation gate and acceptance review, then `retro`.
- Added an **On the shelf** section, so the router can offer to promote a
  shelved skill; `scripts/check-layout.py` lets only this skill name shelved
  items, and requires it to name every shipped one.
- Added harness notes (*Claude Code*, *subagents*) from the portability plan.
- Phase boundaries condensed from `PHASE-BOUNDARIES.md` to four choices.
