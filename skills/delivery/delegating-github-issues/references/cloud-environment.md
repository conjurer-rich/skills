# Cloud environment for the delegator

Advice to the human, not instructions to the delegator. Build one environment for `/delegate` and keep it dedicated; `references/session.md` says why.

## Connectors and network

- Attach only the GitHub connector. Every attached connector's tool list loads on every turn, so mail, drive, calendar, chat, board and analytics connectors cost context on every pass and give the delegator nothing.
- Allow network access to `api.github.com`, plus the package registry your project's bootstrap installs from.

## Setup script

`delegate-status` needs `gh`, `jq`, `git` and `python3`; changesets need `pnpm`. Paste this into the environment's setup script. It stops with a message naming what is missing.

```bash
set -eu

for tool in gh jq git python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "setup: $tool is missing; add it to the environment image" >&2; exit 1; }
done

# Enable pnpm through corepack only when no pnpm is on PATH.
if ! command -v pnpm >/dev/null 2>&1; then
  command -v corepack >/dev/null 2>&1 || { echo "setup: pnpm and corepack are both missing" >&2; exit 1; }
  corepack enable
fi
pnpm --version >/dev/null 2>&1 || { echo "setup: pnpm is on PATH but fails to run" >&2; exit 1; }
```

`corepack enable` replaces a working global `pnpm` with a shim; without a `packageManager` pin in the project, the shim can then download a pnpm release that fails to start, so the script leaves an installed `pnpm` alone and checks that it runs.

Each worktree needs the project's bootstrap commands (**Work** step 5), so name them in the project's root `CLAUDE.md`: for a pnpm project, `pnpm install --frozen-lockfile`.

## Check GitHub access

Run `gh api repos/<owner>/<repo>`. Do not use `gh auth status`: in a cloud container it can report a failed login for the token while `gh api` calls through the cloud proxy succeed, so a failure there is not a problem to chase.

Claude Code: on Claude Code on the web, a project can run the bootstrap in a SessionStart hook in its own `.claude/settings.json`. The plugin ships no such hook, because it would run in every session for every user. Elsewhere, run the bootstrap commands from the setup script or by hand.
