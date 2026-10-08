#!/usr/bin/env bash
#
# The `version` command for changesets/action.
#
# The action does not run its `version` input through a shell: it splits the
# string on whitespace and execs the first word with the rest as arguments, so
# `pnpm changeset version && node …` would hand changesets a literal `&&`.
# This script is the one word the action execs; it runs the two steps itself.
#
#   1. `changeset version` consumes .changeset/*.md, bumps package.json and
#      writes CHANGELOG.md.
#   2. sync-plugin-version.mjs copies the new version into
#      .claude-plugin/plugin.json: Claude Code offers a plugin update when the
#      manifest's version changes, not when commits land.

set -euo pipefail

cd "$(dirname "$0")/.."

pnpm changeset version
node scripts/sync-plugin-version.mjs
