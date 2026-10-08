#!/usr/bin/env bash
#
# Stop hook: remind the agent to commit and push before it stops.
#
# Reads the hook payload on stdin (Claude Code passes JSON with `cwd`), looks
# at the git state of that directory, and prints a reminder when there is
# uncommitted or unpushed work. It never blocks the stop: exit 0 always.
#
# Delegator exemption. The delegating-github-issues skill leaves staged work
# uncommitted in a delegated worktree on purpose (the implementer stages, the
# ship subagent commits later, or a stopped run hands the worktree to the next
# session). A reminder on every one of those stops is noise. The hook stays
# silent when either holds:
#   - the worktree (or any parent up to the repository root) holds a
#     `.delegator/` marker directory, which Work step 5 creates;
#   - DELEGATOR_RUN=1 is set in the environment.
#
# Register in settings.json under hooks.Stop as a command hook.

set -u

payload="$(cat 2>/dev/null || true)"
dir="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$dir" ] || dir="$PWD"

if [ "${DELEGATOR_RUN:-}" = "1" ]; then
  exit 0
fi

# Walk up from the hook's cwd to the repository root looking for the marker.
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$root" ]; then
  probe="$dir"
  while :; do
    if [ -d "$probe/.delegator" ]; then
      exit 0
    fi
    [ "$probe" = "$root" ] && break
    parent="$(dirname "$probe")"
    [ "$parent" = "$probe" ] && break
    probe="$parent"
  done
else
  exit 0
fi

uncommitted="$(git -C "$dir" status --porcelain 2>/dev/null || true)"
unpushed=""
upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [ -n "$upstream" ]; then
  unpushed="$(git -C "$dir" log --oneline "$upstream..HEAD" 2>/dev/null || true)"
fi

if [ -n "$uncommitted" ] || [ -n "$unpushed" ]; then
  echo "Reminder: this checkout has uncommitted or unpushed work. Commit and push before you stop, or say why it stays."
fi
exit 0
