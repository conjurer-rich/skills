#!/usr/bin/env bash
#
# scripts/install-global links global/CLAUDE.md and global/AGENTS.md into the
# places Claude Code, Codex and OpenCode read their global instructions from.
# Every case runs against a throwaway HOME.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install-global"
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

check() { # description command...
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

links_to() { # link expected-target
  [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Git Bash without developer mode cannot make symlinks: `ln -s` copies, and a
# clone checks symlinks out as plain files holding the target's name.
SYMLINKS=false
if ln -s "$work" "$work/probe" 2>/dev/null && [ -L "$work/probe" ]; then SYMLINKS=true; fi

installed() { # target source — a link where the system allows, else a copy
  if [ "$SYMLINKS" = true ]; then links_to "$1" "$2"; else [ ! -L "$1" ] && cmp -s "$1" "$2"; fi
}

run() { # home [args...]
  local home="$1"
  shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$INSTALL" "$@"
}

# The source files are what the installer links to.
if [ "$(git -C "$REPO_ROOT" config core.symlinks)" != false ]; then
  check "global/AGENTS.md is a symlink to CLAUDE.md" links_to "$REPO_ROOT/global/AGENTS.md" CLAUDE.md
fi
check "global/CLAUDE.md points every agent at engineering-practice" \
  grep -q 'load the `engineering-practice` skill' "$REPO_ROOT/global/CLAUDE.md"

# 1. A fresh home with Codex but no OpenCode.
home="$work/fresh"
mkdir -p "$home/.codex"
out="$(run "$home")"
check "Claude Code's CLAUDE.md is linked, creating ~/.claude" installed "$home/.claude/CLAUDE.md" "$REPO_ROOT/global/CLAUDE.md"
check "Codex's AGENTS.md is linked" installed "$home/.codex/AGENTS.md" "$REPO_ROOT/global/CLAUDE.md"
check "OpenCode is skipped when it is not installed" test ! -e "$home/.config/opencode/AGENTS.md"
check "the skip is reported" grep -qi "opencode.*not installed" <<< "$out"

# 2. Running again changes nothing and backs nothing up.
out="$(run "$home")"
check "a second run reports the files as current" grep -Eq "already (linked|current)" <<< "$out"
check "a second run makes no backups" test -z "$(find "$home" -name '*.backup.*' -print -quit)"

# 3. An existing CLAUDE.md, and the old base-CLAUDE.md, are backed up first.
home="$work/existing"
mkdir -p "$home/.claude" "$home/.config/opencode"
printf 'my old instructions\n' > "$home/.claude/CLAUDE.md"
printf 'upstream base\n' > "$home/.claude/base-CLAUDE.md"
run "$home" > /dev/null
check "the existing CLAUDE.md is replaced by the link" installed "$home/.claude/CLAUDE.md" "$REPO_ROOT/global/CLAUDE.md"
backup="$(find "$home/.claude" -name 'CLAUDE.md.backup.*' -print -quit)"
check "the existing CLAUDE.md is kept as a backup" grep -q 'my old instructions' "${backup:-/nonexistent}"
check "base-CLAUDE.md is retired" test ! -e "$home/.claude/base-CLAUDE.md"
base_backup="$(find "$home/.claude" -name 'base-CLAUDE.md.backup.*' -print -quit)"
check "base-CLAUDE.md is kept as a backup" grep -q 'upstream base' "${base_backup:-/nonexistent}"
check "OpenCode's AGENTS.md is linked when it is installed" installed "$home/.config/opencode/AGENTS.md" "$REPO_ROOT/global/CLAUDE.md"

# 4. --copy writes plain files, for systems without symlinks.
home="$work/copy"
mkdir -p "$home/.codex"
run "$home" --copy > /dev/null
check "--copy writes a regular file" test -f "$home/.claude/CLAUDE.md" -a ! -L "$home/.claude/CLAUDE.md"
check "--copy writes the same content" cmp -s "$home/.claude/CLAUDE.md" "$REPO_ROOT/global/CLAUDE.md"
check "--copy writes Codex's file too" cmp -s "$home/.codex/AGENTS.md" "$REPO_ROOT/global/CLAUDE.md"

# 5. --dry-run changes nothing.
home="$work/dry"
mkdir -p "$home/.claude"
printf 'keep me\n' > "$home/.claude/CLAUDE.md"
out="$(run "$home" --dry-run)"
check "--dry-run leaves the existing file alone" grep -q 'keep me' "$home/.claude/CLAUDE.md"
check "--dry-run says what it would do" grep -q "would" <<< "$out"

# 6. A checkout without symlinks: global/AGENTS.md is a plain file holding
#    "CLAUDE.md", and `ln -s` silently copies (as Git Bash does).
repo="$work/nosymlinks"
mkdir -p "$repo/scripts" "$repo/global" "$work/bin"
cp "$INSTALL" "$repo/scripts/install-global"
cp "$REPO_ROOT/global/CLAUDE.md" "$repo/global/CLAUDE.md"
printf 'CLAUDE.md' > "$repo/global/AGENTS.md"
printf '#!/bin/sh
shift; cp "$1" "$2"
' > "$work/bin/ln"
chmod +x "$work/bin/ln"
home="$work/nosymlinks-home"
mkdir -p "$home/.codex"
nosymlinks() { HOME="$home" XDG_CONFIG_HOME="$home/.config" PATH="$work/bin:$PATH" "$repo/scripts/install-global"; }
nosymlinks > /dev/null
check "without symlinks, Codex gets the instructions, not the link's name"   cmp -s "$home/.codex/AGENTS.md" "$repo/global/CLAUDE.md"
out="$(nosymlinks)"
check "without symlinks, a second run reports the copies as current" grep -q "already current" <<< "$out"
check "without symlinks, a second run makes no backups"   test -z "$(find "$home" -name '*.backup.*' -print -quit)"

# 7. An unknown option is refused.
check "an unknown option exits non-zero" bash -c "! HOME='$work/x' '$INSTALL' --bogus >/dev/null 2>&1"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
