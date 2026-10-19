#!/usr/bin/env bash
#
# scripts/install-global puts global/CLAUDE.md where Claude Code, Codex and
# OpenCode read their global instructions from. Every case runs against a
# throwaway HOME.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install-global"
SOURCE="$REPO_ROOT/global/CLAUDE.md"
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

is_copy_of() { # file source
  [ -f "$1" ] && [ ! -L "$1" ] && cmp -s "$1" "$2"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Git Bash without developer mode cannot make symlinks; `ln -s` copies there.
SYMLINKS=false
if ln -s "$work" "$work/probe" 2>/dev/null && [ -L "$work/probe" ]; then SYMLINKS=true; fi

installed() { # target - a link where the system can make one, else a copy
  if [ "$SYMLINKS" = true ]; then links_to "$1" "$SOURCE"; else is_copy_of "$1" "$SOURCE"; fi
}

run() { # home [args...]
  local home="$1"
  shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$INSTALL" "$@"
}

check "global/CLAUDE.md points every agent at engineering-practice" \
  grep -q 'load the `engineering-practice` skill' "$SOURCE"

# 1. A fresh home with Codex but no OpenCode.
home="$work/fresh"
mkdir -p "$home/.codex"
out="$(run "$home")"
check "Claude Code's CLAUDE.md is installed, creating ~/.claude" installed "$home/.claude/CLAUDE.md"
check "Codex's AGENTS.md is installed" installed "$home/.codex/AGENTS.md"
check "OpenCode is skipped when it is not installed" test ! -e "$home/.config/opencode/AGENTS.md"
check "the skip is reported" grep -qi "opencode.*not installed" <<< "$out"

# 2. Running again changes nothing and backs nothing up.
out="$(run "$home")"
if [ "$SYMLINKS" = true ]; then current="already linked"; else current="already current"; fi
check "a second run reports the files as $current" grep -q "$current" <<< "$out"
check "a second run makes no backups" test -z "$(find "$home" -name '*.backup.*' -print -quit)"

# 3. An existing CLAUDE.md, and the old base-CLAUDE.md, are backed up first.
home="$work/existing"
mkdir -p "$home/.claude" "$home/.config/opencode"
printf 'my old instructions\n' > "$home/.claude/CLAUDE.md"
printf 'upstream base\n' > "$home/.claude/base-CLAUDE.md"
run "$home" > /dev/null
check "the existing CLAUDE.md is replaced" installed "$home/.claude/CLAUDE.md"
backup="$(find "$home/.claude" -name 'CLAUDE.md.backup.*' -print -quit)"
check "the existing CLAUDE.md is kept as a backup" grep -q 'my old instructions' "${backup:-/nonexistent}"
check "base-CLAUDE.md is retired" test ! -e "$home/.claude/base-CLAUDE.md"
base_backup="$(find "$home/.claude" -name 'base-CLAUDE.md.backup.*' -print -quit)"
check "base-CLAUDE.md is kept as a backup" grep -q 'upstream base' "${base_backup:-/nonexistent}"
check "OpenCode's AGENTS.md is installed when OpenCode is" installed "$home/.config/opencode/AGENTS.md"

# 4. --copy writes plain files, for systems without symlinks.
home="$work/copy"
mkdir -p "$home/.codex"
run "$home" --copy > /dev/null
check "--copy writes Claude Code's file as a copy" is_copy_of "$home/.claude/CLAUDE.md" "$SOURCE"
check "--copy writes Codex's file as a copy" is_copy_of "$home/.codex/AGENTS.md" "$SOURCE"

# 5. Where symlinks work, linking replaces a copy left by an earlier --copy,
#    so the file follows `git pull` again.
if [ "$SYMLINKS" = true ]; then
  out="$(run "$home")"
  check "linking replaces an earlier copy with a link" links_to "$home/.claude/CLAUDE.md" "$SOURCE"
fi

# 6. --dry-run changes nothing.
home="$work/dry"
mkdir -p "$home/.claude"
printf 'keep me\n' > "$home/.claude/CLAUDE.md"
out="$(run "$home" --dry-run)"
check "--dry-run leaves the existing file alone" grep -q 'keep me' "$home/.claude/CLAUDE.md"
check "--dry-run says what it would do" grep -q "would" <<< "$out"

# 7. Without symlink support `ln -s` silently copies, as Git Bash does.
mkdir -p "$work/bin"
printf '#!/bin/sh\nshift; cp "$1" "$2"\n' > "$work/bin/ln"
chmod +x "$work/bin/ln"
home="$work/nosymlinks"
mkdir -p "$home/.codex" "$home/.config/opencode"
nosymlinks() { PATH="$work/bin:$PATH" run "$home"; }
nosymlinks > /dev/null
check "without symlinks, Claude Code gets a copy" is_copy_of "$home/.claude/CLAUDE.md" "$SOURCE"
check "without symlinks, Codex gets a copy" is_copy_of "$home/.codex/AGENTS.md" "$SOURCE"
check "without symlinks, OpenCode gets a copy" is_copy_of "$home/.config/opencode/AGENTS.md" "$SOURCE"
out="$(nosymlinks)"
check "without symlinks, a second run reports the copies as current" grep -q "already current" <<< "$out"
check "without symlinks, a second run makes no backups" \
  test -z "$(find "$home" -name '*.backup.*' -print -quit)"

# 8. --help prints the whole usage, and an unknown option is refused.
check "--help lists every option" grep -q -- "--dry-run" <<< "$("$INSTALL" --help)"
check "an unknown option exits non-zero" bash -c "! HOME='$work/x' '$INSTALL' --bogus >/dev/null 2>&1"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
