# Working on craft

This repository is the `craft` plugin. `AGENTS.md` is a symlink to this file.

## Layout

- A shipped skill lives at `skills/<bucket>/<name>/SKILL.md` (buckets:
  `engineering`, `architecture`, `delivery`, `writing`) **and** is listed in
  `.claude-plugin/plugin.json` → `skills`. Both, or CI fails.
- `skills/in-progress/` holds drafts and `skills/deprecated/` holds aliases;
  neither is listed in `plugin.json`.
- `shelf/{skills,agents,commands}/` holds items kept but not installed.
  Shipped files must not route to a shelved item; promote it first.
- `agents/` and `commands/` are discovered by default; do not list them in
  `plugin.json`.
- Never create a `.claude/skills/` inside this repository: Claude Code would
  load every skill a second time. The eval harness builds its workspaces in a
  temp directory for that reason.

## Before you push

- `./test/run.sh` passes. It includes `scripts/check-layout.py` (manifest ↔
  folders, links, no references to shelved items) and
  `scripts/check-licensing.py`.
- A changeset (`pnpm changeset`) for anything a user would notice. Never edit
  `version` in `package.json` or `plugin.json` by hand; `scripts/version.sh`
  does both.

## Writing skills

- Name capabilities, not one harness's tools: "spawn a subagent", not "use
  the Agent tool". Where only a Claude Code tool will do, say so in a note
  labelled "Claude Code:" with what to do elsewhere.
- Refer to files inside a skill relatively. Do not name `~/.claude/...` paths.
- Keep `description` front-loaded with when to use the skill; it is loaded
  into every session.

## Borrowing from elsewhere

- Copying text from another project: put its licence verbatim in the skill's
  folder as `LICENSE` (and its `NOTICE`, for Apache 2.0), record the pinned
  commit and what changed in `references/source-notes.md`, and add a row to
  `ACKNOWLEDGEMENTS.md`.
- Taking ideas without text: cite them in `source-notes.md` and say
  "ideas only, no text copied".
- No clear licence, no copied text. CC BY-SA material stays in its own folder
  under its own licence.
