# review: source notes

Adapted from Matt Pocock's `code-review`.

## Source

- Repository: <https://github.com/mattpocock/skills>
- Pinned revision: [`b0618bc4`](https://github.com/mattpocock/skills/tree/b0618bc436ad893b3c5e84e55fba86586d34a404)
- Folder: [`skills/engineering/code-review`](https://github.com/mattpocock/skills/tree/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/code-review)
- Licence: MIT, Copyright (c) 2026 Matt Pocock. The full notice is in
  [`../LICENSE`](../LICENSE).

## Taken

- The two axes, Standards and Spec, reviewed in separate subagents and
  reported side by side without re-ranking, and the reason for keeping them
  apart.
- Pinning the fixed point once with a three-dot diff, and failing early on a
  bad ref or empty diff.
- The order for finding the spec, and the rule that `CODING_STANDARDS.md` /
  `CONTRIBUTING.md` are always on the standards list.
- The Fowler smell baseline (*Refactoring*, chapter 3) with its two binding
  rules: the repository overrides it, and every smell is a judgement call.
- The subagent briefs and the per-axis summary line.

## Changed (Richard Allen, 2026-10-08)

- Named `review` rather than `code-review`, which collides with Claude
  Code's built-in reviewer; the skill says to use the harness's own reviewer
  for bugs.
- The Standards axis also loads up to three craft skills chosen from the
  diff's traits (decision D9 in the extraction plan).
- The Spec axis runs craft's `acceptance-review` instead of a bespoke brief.
- With no ref, the fixed point defaults to the merge-base with the default
  branch instead of asking; `plans/` is added to the spec search.
- Runs the axes one after the other where the harness has no subagents.
- No dependency on Matt's issue-tracker setup skill.
