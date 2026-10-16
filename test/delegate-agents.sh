#!/usr/bin/env bash
#
# Guard the delegator's narrow agent types. A dispatch that names a
# `craft:delegate-*` type with no file under agents/ fails at run time in the
# middle of a delegation, so catch it here. Each type keeps a narrow tools list,
# the reviewer cannot edit source, and `general-purpose` survives only as the
# documented fallback.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills/delivery/delegating-github-issues"
COMMAND_DIR="$REPO_ROOT/skills/delivery/delegate"
AGENTS_DIR="$REPO_ROOT/agents"
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

frontmatter() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"
}

field() {
  frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -n 1
}

# A field's text, with a folded or literal block scalar (`>`, `|`) read from
# its indented continuation lines.
field_text() {
  frontmatter "$1" | awk -v key="$2" '
    in_block && /^[[:space:]]+[^[:space:]]/ { sub(/^[[:space:]]+/, ""); printf "%s ", $0; next }
    in_block { exit }
    index($0, key ":") == 1 {
      value = substr($0, length(key) + 2); sub(/^[[:space:]]+/, "", value)
      if (value ~ /^[>|][-+]?$/) { in_block = 1; next }
      print value; exit
    }'
}

# Every delegate-* type the skill or the /delegate command names has an agent file.
named="$(grep -rhoE 'craft:delegate-[a-z0-9-]+' "$SKILL_DIR" "$COMMAND_DIR" | sort -u || true)"
if [ -z "$named" ]; then
  fail "the skill dispatches at least one craft:delegate-* type"
else
  pass "the skill dispatches at least one craft:delegate-* type"
fi
for qualified in $named; do
  type="${qualified#craft:}"
  if [ -f "$AGENTS_DIR/$type.md" ]; then
    pass "$qualified has agents/$type.md"
  else
    fail "$qualified is dispatched but agents/$type.md does not exist"
  fi
done

# The four types exist with a complete frontmatter and a restricted tools list.
for type in delegate-implementer delegate-reviewer delegate-walkthrough delegate-mechanical; do
  file="$AGENTS_DIR/$type.md"
  if [ ! -f "$file" ]; then
    fail "agents/$type.md exists"
    continue
  fi
  [ "$(field "$file" name)" = "$type" ] && pass "$type: name matches the file" || fail "$type: name matches the file"
  [ -n "$(field_text "$file" description | tr -d '[:space:]')" ] && pass "$type: has a description" || fail "$type: has a description"
  [ -n "$(field "$file" model)" ] && pass "$type: has a model" || fail "$type: has a model"
  tools="$(field "$file" tools)"
  if [ -n "$tools" ] && ! printf '%s' "$tools" | grep -Eq '\*|(^|[ ,])All([ ,]|$)'; then
    pass "$type: has a restricted tools list"
  else
    fail "$type: has a restricted tools list"
  fi
done

# The reviewer reads and reports; it never edits source.
reviewer_tools="$(field "$AGENTS_DIR/delegate-reviewer.md" tools 2>/dev/null || true)"
if printf '%s' "$reviewer_tools" | grep -Eq '(^|[ ,])(Edit|MultiEdit|NotebookEdit)([ ,]|$)'; then
  fail "delegate-reviewer has no edit tool"
else
  pass "delegate-reviewer has no edit tool"
fi

# The reviewer runs the full suite as a background task and waits for it, so it
# needs Monitor and TaskOutput, but it may not stop a task (no TaskStop).
for tool in Monitor TaskOutput; do
  if printf '%s' "$reviewer_tools" | grep -Eq "(^|[ ,])$tool([ ,]|$)"; then
    pass "delegate-reviewer has $tool to wait on a background task"
  else
    fail "delegate-reviewer has $tool to wait on a background task"
  fi
done
if printf '%s' "$reviewer_tools" | grep -Eq '(^|[ ,])TaskStop([ ,]|$)'; then
  fail "delegate-reviewer has no TaskStop"
else
  pass "delegate-reviewer has no TaskStop"
fi

# hand-back.md makes the narrow types the default dispatch.
HAND_BACK="$SKILL_DIR/references/hand-back.md"
if grep -qF 'its `subagent_type` is the narrow agent type for its role' "$HAND_BACK"; then
  pass "hand-back.md makes the role's delegate-* type the default subagent_type"
else
  fail "hand-back.md makes the role's delegate-* type the default subagent_type"
fi

# hand-back.md keeps the documented fallback paragraph.
if grep -E '^\*\*Fallback\.\*\*' "$HAND_BACK" | grep -qF 'general-purpose'; then
  pass "hand-back.md has a **Fallback.** paragraph naming general-purpose"
else
  fail "hand-back.md has a **Fallback.** paragraph naming general-purpose"
fi

# Every mention of general-purpose in the skill or the /delegate command is
# fallback wording, on its own line or the line before (prose wraps).
FALLBACK_WORDING='\*\*Fallback\.\*\*|fall back to|isn.t available|not available|not installed'
mentions=0
while IFS=: read -r file line _; do
  [ -n "$file" ] || continue
  mentions=$((mentions + 1))
  start=$((line > 1 ? line - 1 : 1))
  where="${file#"$REPO_ROOT"/}:$line"
  if sed -n "${start},${line}p" "$file" | grep -qiE "$FALLBACK_WORDING"; then
    pass "$where names general-purpose only as the fallback"
  else
    fail "$where names general-purpose outside the documented fallback"
  fi
done <<EOF_MENTIONS
$(grep -rnF 'general-purpose' "$SKILL_DIR" "$COMMAND_DIR" || true)
EOF_MENTIONS
for file in hand-back harness; do
  if grep -qF 'general-purpose' "$SKILL_DIR/references/$file.md"; then
    pass "$file.md names the general-purpose fallback"
  else
    fail "$file.md names the general-purpose fallback"
  fi
done

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
