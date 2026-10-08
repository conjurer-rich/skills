# Retro: source notes

This skill is an attributed adaptation of Matt Pocock's `retro`.

## Source

- Repository: <https://github.com/mattpocock/skills>
- Pinned revision: [`b0618bc4`](https://github.com/mattpocock/skills/tree/b0618bc436ad893b3c5e84e55fba86586d34a404)
- Files:
  [`skills/engineering/retro/SKILL.md`](https://github.com/mattpocock/skills/blob/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/retro/SKILL.md),
  [`agents/openai.yaml`](https://github.com/mattpocock/skills/blob/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/retro/agents/openai.yaml)
- Licence: MIT, Copyright (c) 2026 Matt Pocock. The full notice is in
  [`../LICENSE`](../LICENSE).

## Taken

- Retrospectives change the agent's **environment**, not the code.
- The categories navigation, automated checks, coding standards (mechanical
  violations become checks; written standards keep judgement calls), global
  steering files and no-ops, tool economy and information access, each with
  its "use when".
- The implementation/review split and the guidance on where changes live.

## Changed (Richard Allen, 2026-10-08)

- Added the **Missed skills** category, which compares the session against
  craft's map in `../ask/SKILL.md`, including shelved skills and gaps for
  `find-skills`.
- The writing guide (`writing-for-agents`) loads only when installed.
- Reading a long session can be split across subagents; harness-specific log
  locations sit in a "Claude Code:" note.
- No proposal is applied until the user picks it; owners are chosen with
  `expectations`.
- `CODING_STANDARDS.md` is generalised to the repository's written
  standards, wherever they live.
