# Source Notes

## Pinned origin

The formatting guidance adapts Adam Bulmer's MIT-licensed Mintuz writing
bundle. The direct formatting source was introduced at
`225ecb470307fe5142c070ebf1b239e02fd0fe07` and remained blob-identical through
upstream snapshot `280c015271cbf539f7950469df6f515cc41be6ec`, the last
upstream tip before local introduction commit
`9f84fd9268971fe6c4b4d816eabb5edff83c9c57`:

- [formatting.md](https://github.com/mintuz/skills/blob/280c015271cbf539f7950469df6f515cc41be6ec/plugins/core/skills/writing/formatting.md)
- [writing SKILL.md](https://github.com/mintuz/skills/blob/280c015271cbf539f7950469df6f515cc41be6ec/plugins/core/skills/writing/SKILL.md)
- [MIT licence](https://github.com/mintuz/skills/blob/280c015271cbf539f7950469df6f515cc41be6ec/LICENSE)

The complete Adam Bulmer notice is preserved in `../LICENSE`.

## Local adaptation

The local bundle retains the source's front-loaded, skimmable structure and
formatting heuristics, but makes numeric rules contextual, adds
repository-owned documentation lifecycles, verified-behaviour guidance,
documentation quality gates, and agent-facing documentation concerns.

## anthropics/oncall-kit

- Repository: [anthropics/oncall-kit](https://github.com/anthropics/oncall-kit)
- Revision: `c03282cd5381a5a2e12e32bfb3c8957d52ce01f1`
- Idea taken: "Communication discipline" rule 10 in its `CLAUDE.md` — write
  for a reader who missed the thread, describe system behaviour instead of
  naming chart shapes, and take facts but not vocabulary from machine- or
  agent-written feeds.
- What craft changed: generalised from on-call updates to any technical
  document, stated as the **Written for a fresh reader** principle with a
  matching checklist item, and reworded throughout.
- Licence status: ideas only, no text copied.
