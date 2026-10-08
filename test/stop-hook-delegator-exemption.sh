#!/usr/bin/env bash
#
# Guard the stop hook's delegator exemption. The delegating-github-issues
# skill leaves staged work uncommitted in a delegated worktree by design, and
# a stop hook that nags to commit and push fired on every delegator stop in
# the aborted cloud run. The hook must stay silent when a `.delegator/`
# marker directory is present or DELEGATOR_RUN=1 is set, and must still nag
# otherwise, or the exemption has swallowed the hook.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/hooks/stop-hook-git-check.sh"
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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A repository with staged, uncommitted work, like a delegated worktree after
# the implementer returns.
REPO="$TMP/worktree"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name test
echo one > "$REPO/file"
git -C "$REPO" add file
git -C "$REPO" commit -q -m init
echo two > "$REPO/file"
git -C "$REPO" add file

run_hook() {
  # $1: cwd for the payload; extra env is passed by the caller.
  printf '{"cwd":"%s"}' "$1" | bash "$HOOK"
}

out="$(run_hook "$REPO")"
if [ -n "$out" ]; then
  pass "the hook nags on staged work with no marker"
else
  fail "the hook nags on staged work with no marker"
fi

out="$(DELEGATOR_RUN=1 run_hook "$REPO")"
if [ -z "$out" ]; then
  pass "DELEGATOR_RUN=1 silences the hook"
else
  fail "DELEGATOR_RUN=1 silences the hook"
fi

mkdir -p "$REPO/.delegator"
echo session > "$REPO/.delegator/run"
out="$(run_hook "$REPO")"
if [ -z "$out" ]; then
  pass "a .delegator/ marker silences the hook"
else
  fail "a .delegator/ marker silences the hook"
fi

# The marker is at the worktree root; a stop from a subdirectory must still
# see it.
mkdir -p "$REPO/packages/web"
out="$(run_hook "$REPO/packages/web")"
if [ -z "$out" ]; then
  pass "the marker is found from a subdirectory of the worktree"
else
  fail "the marker is found from a subdirectory of the worktree"
fi

rm -rf "$REPO/.delegator"
out="$(run_hook "$REPO")"
if [ -n "$out" ]; then
  pass "removing the marker brings the nag back"
else
  fail "removing the marker brings the nag back"
fi

# The hook must never block a stop.
if printf '{"cwd":"%s"}' "$REPO" | bash "$HOOK" > /dev/null; then
  pass "the hook exits 0"
else
  fail "the hook exits 0"
fi

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
