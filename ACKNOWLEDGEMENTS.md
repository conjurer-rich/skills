# Acknowledgements

craft stands on other people's work. This file lists every source whose text
or structure it carries, under which licence, and where the notice lives. The
CI check in `scripts/check-licensing.py` fails when a nested notice has no row
here, or a row points at a notice that no longer exists.

## People and projects

- **Paul Hammond** ([`citypaul/.dotfiles`](https://github.com/citypaul/.dotfiles)):
  the original development framework this plugin grew from, and most of its
  skills, agents and commands. MIT, root [`LICENSE`](LICENSE).
- **Matt Pocock** ([`mattpocock/skills`](https://github.com/mattpocock/skills)):
  deep-module design and architecture-improvement skills, and the repository
  shape this one borrows (buckets, explicit `plugin.json` skill list).
- **Adam Bulmer** ([`mintuz/skills`](https://github.com/mintuz/skills)):
  acceptance review, system-complexity reduction, code-shape rendering,
  technical writing and `wtf`.
- **Addy Osmani** ([`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills)):
  API design.
- **Vercel** ([`vercel-labs/skills`](https://github.com/vercel-labs/skills)):
  skill discovery.
- **Aanand Prasad, Ben Firshman, Carl Tashian and Eva Parish**
  ([*Command Line Interface Guidelines*](https://clig.dev)): CLI design.

## Licensed sources

| Item | Upstream | Licence | Copyright | Pinned revision | Notice |
| --- | --- | --- | --- | --- | --- |
| everything without a nested notice | `citypaul/.dotfiles` | MIT | Paul Hammond (2024) | see [`PROVENANCE.md`](PROVENANCE.md) | [`LICENSE`](LICENSE) |
| `codebase-design` | `mattpocock/skills` | MIT | Matt Pocock (2026) | `66898f60` | [`skills/architecture/codebase-design/LICENSE`](skills/architecture/codebase-design/LICENSE) |
| `improve-codebase-architecture` | `mattpocock/skills` | MIT | Matt Pocock (2026) | `66898f60` | [`skills/architecture/improve-codebase-architecture/LICENSE`](skills/architecture/improve-codebase-architecture/LICENSE) |
| `acceptance-review` | `mintuz/skills` | MIT | Adam Bulmer (2025) | `976d4a0c` | [`skills/delivery/acceptance-review/LICENSE`](skills/delivery/acceptance-review/LICENSE) |
| `reduce-system-complexity` | `mintuz/skills` | MIT | Adam Bulmer (2025) | `d698a88f` | [`skills/engineering/reduce-system-complexity/LICENSE`](skills/engineering/reduce-system-complexity/LICENSE) |
| `technical-writing` | `mintuz/skills` | MIT | Adam Bulmer (2025) | `280c0152` | [`skills/writing/technical-writing/LICENSE`](skills/writing/technical-writing/LICENSE) |
| `wtf` | `mintuz/skills` | MIT | Adam Bulmer (2025) | `e436942e` | [`skills/writing/wtf/LICENSE`](skills/writing/wtf/LICENSE) |
| `render-code-shape` (shelf) | `mintuz/skills` | MIT | Adam Bulmer (2025) | `976d4a0c` | [`shelf/skills/render-code-shape/LICENSE`](shelf/skills/render-code-shape/LICENSE) |
| `api-design` | `addyosmani/agent-skills` | MIT | Addy Osmani (2025) | `7676817c` | [`skills/architecture/api-design/LICENSE`](skills/architecture/api-design/LICENSE) |
| `find-skills` | `vercel-labs/skills` | MIT | Vercel, Inc. (2026) | `0b8fb22a` | [`skills/writing/find-skills/LICENSE`](skills/writing/find-skills/LICENSE) |
| `cli-design` (shelf) | `cli-guidelines/cli-guidelines` | **CC BY-SA 4.0** | Prasad, Firshman, Tashian, Parish | `697d6a29` | [`shelf/skills/cli-design/LICENSE`](shelf/skills/cli-design/LICENSE) |
| `diagrams` | original rewrite (earlier versions drew on `markdown-viewer/skills`) | MIT (root) | — | — | [`skills/writing/diagrams/NOTICE`](skills/writing/diagrams/NOTICE) |

Each adapted skill's `source-notes.md` records exactly what was taken and what
changed. A skill that cites a repository but copies no text says so in its
source notes ("ideas only, no text copied").

## Ideas

Books, articles and talks that shaped the skills without lending them text
(Fowler, Evans, Feathers, Ousterhout, Cockburn, Ottinger, Farley and many
more) are credited in [`skills/REFERENCES.md`](skills/REFERENCES.md) and in each
skill's source notes.
