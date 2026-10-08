# craft

Engineering skills, agents and commands for coding agents: test-driven
development, testing, refactoring, architecture, delivery and technical writing.
craft is a Claude Code plugin; Codex support is planned.

It grew out of Paul Hammond's [`citypaul/.dotfiles`](https://github.com/citypaul/.dotfiles)
and borrows from Matt Pocock's [`mattpocock/skills`](https://github.com/mattpocock/skills)
and others — see [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## Install

```sh
claude plugin marketplace add conjurer-rich/skills
claude plugin install craft@conjurer
```

Skills load as `craft:<name>` (for example `craft:tdd`), agents as
`craft:<name>` in the agent list, and commands as `/delegate`, `/plan` and
`/continue`. The plugin also installs a Stop hook that warns about
uncommitted or unpushed work.

### Global instructions

The plugin cannot write your global `CLAUDE.md`, so a short script does. From a
clone of this repository:

```sh
scripts/install-global            # or --copy where symlinks are unavailable
```

It links `~/.claude/CLAUDE.md` to [`global/CLAUDE.md`](global/CLAUDE.md), and
`AGENTS.md` for Codex and OpenCode when they are installed, backing up any
existing file. The file is short on purpose: it tells every session to load
`engineering-practice`, which carries the guidelines, and holds a few personal
preferences. `git pull` updates it.

### Updates

Claude Code offers an update when the plugin's version changes. To update by
hand: `claude plugin marketplace update conjurer`, then
`claude plugin update craft@conjurer`.

**Moving from `craft@conjurer-dotfiles`:** uninstall that first
(`claude plugin uninstall craft@conjurer-dotfiles`), so the two copies do not
load every skill twice. The names are unchanged.

## What is in it

| Folder | Holds |
| --- | --- |
| `skills/engineering/` | day-to-day code work: `tdd`, `testing`, `refactoring`, `typescript-strict`, `debugging`, `mutation-testing`, … |
| `skills/architecture/` | design and structure: `hexagonal-architecture`, `domain-driven-design`, `codebase-design`, `api-design`, `observability`, … |
| `skills/delivery/` | getting work shipped: `delegating-github-issues`, `planning`, `specification`, `story-splitting`, `acceptance-review`, … |
| `skills/writing/` | knowledge and prose: `technical-writing`, `diagrams`, `ubiquitous-language`, `expectations`, … |
| `agents/` | `tdd-guardian`, `refactor-scan`, `twelve-factor-audit`, `adr`, `learn` |
| `commands/` | `/delegate`, `/plan`, `/continue` |
| `shelf/` | skills, agents and commands kept in the repository but **not installed** |
| `skills/deprecated/` | aliases kept for one release, then deleted |
| `global/` | the global `CLAUDE.md` (and `AGENTS.md`, a link to it) that `scripts/install-global` puts in place |

Start with `craft:engineering-practice`: it carries the engineering guidelines,
and its `references/routing.md` says which skill to load for which kind of
work.

### The shelf

A shelved item costs nothing at runtime: it is not listed in
`.claude-plugin/plugin.json`, so its description does not load into every
session. Promote one by moving its folder into a `skills/<bucket>/` (or
`agents/`, `commands/`) and, for a skill, adding its path to `plugin.json`.
`scripts/skill-usage.py` shows which items you actually use; re-run it now and
then to decide what ships.

## Working on craft

```sh
pnpm install
./test/run.sh          # layout, licensing, skill guidance and delegation tests
```

- Repository conventions for people and agents: [CLAUDE.md](CLAUDE.md)
  (`AGENTS.md` points at the same file).
- Every change that users would notice gets a changeset: `pnpm changeset`.
  Merging to `main` opens a "chore: version packages" PR; merging that tags the
  release and bumps `plugin.json`.
- Skill evaluations (promptfoo, real tokens) live in `evals/skills/`; see its
  README.

## Licence

MIT, except where a nested `LICENSE` or `NOTICE` says otherwise
(`shelf/skills/cli-design/` is CC BY-SA 4.0). See [LICENSE](LICENSE),
[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) and [PROVENANCE.md](PROVENANCE.md).
