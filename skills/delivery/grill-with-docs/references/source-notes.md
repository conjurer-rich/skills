# grill-with-docs: source notes

Adapted from Matt Pocock's `grill-with-docs`.

## Source

- Repository: <https://github.com/mattpocock/skills>
- Pinned revision: [`b0618bc4`](https://github.com/mattpocock/skills/tree/b0618bc436ad893b3c5e84e55fba86586d34a404)
- Folder: [`skills/engineering/grill-with-docs`](https://github.com/mattpocock/skills/tree/b0618bc436ad893b3c5e84e55fba86586d34a404/skills/engineering/grill-with-docs)
- Licence: MIT, Copyright (c) 2026 Matt Pocock. The full notice is in
  [`../LICENSE`](../LICENSE).

## Taken

- The idea and `agents/openai.yaml`: a user-invoked grilling session that writes the repository's docs as it goes.

## Changed (Richard Allen, 2026-10-08)

- Matt's version pairs `grilling` with his `domain-modeling` skill. This one records terms through craft's `ubiquitous-language` protocol and hard-to-reverse decisions through the `adr` agent (or the repository's decision folder elsewhere), so craft keeps one glossary system and one decision mechanism.
- Adds a completion criterion: the frontier is empty and every settled term and decision is recorded, written only after the user confirms.
