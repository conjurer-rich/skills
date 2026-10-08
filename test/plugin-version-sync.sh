#!/usr/bin/env bash
#
# Guard the plugin manifest version. Claude Code detects a marketplace plugin
# update from plugin.json's `version`, not from git commits, so a manifest
# that lags package.json pins every installed copy to an old release.
# The manifest sat at 4.12.2 for eleven releases before this test existed.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE="$REPO_ROOT/package.json"
MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"
SYNC="$REPO_ROOT/scripts/sync-plugin-version.mjs"
WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
FAILURES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
}

json_version() {
  node -p "require('$1').version"
}

# 1. The committed manifest matches the committed release version.
release_version="$(json_version "$RELEASE")"
manifest_version="$(json_version "$MANIFEST")"
if [ "$release_version" = "$manifest_version" ]; then
  pass "plugin.json version ($manifest_version) matches package.json"
else
  fail "plugin.json version ($manifest_version) lags package.json ($release_version); run node scripts/sync-plugin-version.mjs"
fi

# 2. The release workflow runs the sync in the same step as changeset version,
#    so the "chore: version packages" PR carries both bumps. changesets/action
#    execs its `version` input without a shell (it splits on whitespace), so
#    the input must be one command, not an `a && b` chain: runs 27 and 28
#    failed with "Too many arguments passed to changesets" on exactly that.
VERSION_SCRIPT="$REPO_ROOT/scripts/version.sh"
if grep -Fq 'version: bash scripts/version.sh' "$WORKFLOW"; then
  pass "release.yml versions through scripts/version.sh"
else
  fail "release.yml versions through scripts/version.sh"
fi
if grep -Eq '^\s*version: .*&&' "$WORKFLOW"; then
  fail "the version input is one command, not a shell chain"
else
  pass "the version input is one command, not a shell chain"
fi
if grep -Fq 'pnpm changeset version' "$VERSION_SCRIPT" && grep -Fq 'node scripts/sync-plugin-version.mjs' "$VERSION_SCRIPT"; then
  pass "scripts/version.sh runs changeset version then the sync"
else
  fail "scripts/version.sh runs changeset version then the sync"
fi

# 3. The sync script rewrites the version line and nothing else, and is
#    idempotent. Exercised on a copy of the repo layout so the checkout stays
#    untouched.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/.claude-plugin"
cp "$SYNC" "$TMP/scripts/"
printf '{\n  "name": "@conjurer-rich/skills",\n  "version": "9.9.9"\n}\n' > "$TMP/package.json"
cp "$MANIFEST" "$TMP/.claude-plugin/plugin.json"

if node "$TMP/scripts/sync-plugin-version.mjs" > /dev/null \
  && [ "$(json_version "$TMP/.claude-plugin/plugin.json")" = "9.9.9" ]; then
  pass "sync script copies the release version into the manifest"
else
  fail "sync script copies the release version into the manifest"
fi

expected="$(sed "s/\"version\": \"$manifest_version\"/\"version\": \"9.9.9\"/" "$MANIFEST")"
if [ "$(cat "$TMP/.claude-plugin/plugin.json")" = "$expected" ]; then
  pass "sync script changes only the version line"
else
  fail "sync script changes only the version line"
fi

before="$(cat "$TMP/.claude-plugin/plugin.json")"
if node "$TMP/scripts/sync-plugin-version.mjs" > /dev/null \
  && [ "$(cat "$TMP/.claude-plugin/plugin.json")" = "$before" ]; then
  pass "sync script is idempotent"
else
  fail "sync script is idempotent"
fi

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
