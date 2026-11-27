# Delegating GitHub issues: source notes

## Matt Pocock's `pr` skill

The PR body contract's **Summary** (`references/work.md`, step 10) takes two
ideas from Matt Pocock's `pr` skill, which credits Dex Horthy's `show-me`
skill (Humanlayer):

- Open with the smallest view that makes the change clear (pseudocode, a call
  tree, a file tree, a diagram, or a diff sketch of one).
- Name the merge danger: whether the change is a one-way or two-way door, and
  its blast radius.

Source: <https://github.com/mattpocock/skills>, pinned at
[`49dd158`](https://github.com/mattpocock/skills/tree/49dd158d1076134a641b33efb035946536778336/skills/engineering/pr),
`skills/engineering/pr/SKILL.md`: ideas only, no text copied. The skill's
before-and-after evidence section was not taken: the contract's **TDD
evidence** and **UX walkthrough** sections already carry it.

## anthropics/oncall-kit

The **Reporting rules** in `references/watch.md` take four ideas from the
standing rules of Anthropic's oncall-kit plugin, where they govern its
`weather` status posts:

- Post only for an event from a closed list. Never improvise one, and never
  suppress one.
- Diff against the last message readers actually received.
- A failed fetch is reported as unavailable, never as healthy.
- A heuristic applied leaves a trace in the output.

Source: <https://github.com/anthropics/oncall-kit>, pinned at
[`c03282cd`](https://github.com/anthropics/oncall-kit/tree/c03282cd5381a5a2e12e32bfb3c8957d52ce01f1),
`CLAUDE.md` (rules 16 to 19): ideas only, no text copied. Fork:
<https://github.com/conjurer-rich/oncall-kit>.
