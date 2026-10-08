#!/usr/bin/env bash
#
# scripts/check-layout.py and scripts/check-licensing.py guard the plugin's
# shape and its licence notices. This test runs both on the repository, then
# on a scratch copy with one fault planted at a time, so a check that stops
# catching its fault fails here.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

if python3 "$REPO_ROOT/scripts/check-layout.py" > /dev/null; then
  pass "the repository's layout and references hold"
else
  python3 "$REPO_ROOT/scripts/check-layout.py" || true
  fail "the repository's layout and references hold"
fi
if python3 "$REPO_ROOT/scripts/check-licensing.py" > /dev/null; then
  pass "the repository's licences and acknowledgements hold"
else
  python3 "$REPO_ROOT/scripts/check-licensing.py" || true
  fail "the repository's licences and acknowledgements hold"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fresh_copy() {
  rm -rf "$work/repo"
  mkdir -p "$work/repo"
  (cd "$REPO_ROOT" && cp -R .claude-plugin skills shelf agents commands scripts LICENSE ACKNOWLEDGEMENTS.md portability.json "$work/repo/")
}

expect_failure() { # description check-script expected-text
  if out="$(python3 "$work/repo/scripts/$2" 2>&1)"; then
    fail "$1 (the check passed)"
  elif grep -Fq -- "$3" <<< "$out"; then
    pass "$1"
  else
    echo "$out"
    fail "$1 (the check failed, but not with: $3)"
  fi
}

fresh_copy
mkdir -p "$work/repo/skills/engineering/unlisted"
printf -- '---\nname: unlisted\ndescription: x\n---\n' > "$work/repo/skills/engineering/unlisted/SKILL.md"
expect_failure "a skill missing from plugin.json is caught" check-layout.py "skills/engineering/unlisted: not listed in plugin.json"

fresh_copy
printf '\nSee `panel-review` for more.\n' >> "$work/repo/skills/engineering/tdd/SKILL.md"
expect_failure "a shipped skill naming a shelved one is caught" check-layout.py "names \`panel-review\`, which is not shipped"

fresh_copy
printf '\n[gone](does-not-exist.md)\n' >> "$work/repo/skills/engineering/tdd/SKILL.md"
expect_failure "a broken relative link is caught" check-layout.py "broken link does-not-exist.md"

# craft:ask is the router: every shipped item must appear in it, and it is the
# one shipped file allowed to name a shelved item (to offer a promotion).
fresh_copy
if [ -f "$work/repo/skills/delivery/ask/SKILL.md" ]; then
  printf '\nThere is a shelved `panel-review`; promote it if needed.\n' >> "$work/repo/skills/delivery/ask/SKILL.md"
  if python3 "$work/repo/scripts/check-layout.py" > /dev/null 2>&1; then
    pass "craft:ask may name a shelved item"
  else
    fail "craft:ask may name a shelved item"
  fi
else
  fail "craft:ask exists at skills/delivery/ask"
fi

fresh_copy
python3 - "$work/repo" <<'PY'
import re, sys
from pathlib import Path
ask = Path(sys.argv[1]) / "skills/delivery/ask/SKILL.md"
text = ask.read_text(encoding="utf-8")
ask.write_text(re.sub(r"`(?:craft:)?mutation-testing`", "`something-else`", text), encoding="utf-8")
PY
expect_failure "a shipped skill missing from craft:ask is caught" check-layout.py "mutation-testing: not listed in craft:ask"

# scripts/check-portability.py: skills that claim to run in Codex must not
# lean on Claude Code tools, and the router must say which ones do.
if python3 "$REPO_ROOT/scripts/check-portability.py" > /dev/null; then
  pass "the declared portability tiers hold"
else
  fail "the declared portability tiers hold"
  python3 "$REPO_ROOT/scripts/check-portability.py" || true
fi

fresh_copy
printf '\nDispatch it with the Agent tool.\n' >> "$work/repo/skills/engineering/tdd/SKILL.md"
expect_failure "a portable skill naming a Claude Code tool is caught" check-portability.py "names 'Agent tool' outside a \"Claude Code:\" note"

fresh_copy
printf '\n- Claude Code: dispatch it with the Agent tool; elsewhere, run it inline.\n' >> "$work/repo/skills/engineering/tdd/SKILL.md"
if python3 "$work/repo/scripts/check-portability.py" > /dev/null 2>&1; then
  pass "a Claude Code tool inside a \"Claude Code:\" note is allowed"
else
  fail "a Claude Code tool inside a \"Claude Code:\" note is allowed"
fi

fresh_copy
printf '\nLogs live under ~/.claude/projects.\n' >> "$work/repo/skills/delivery/review/SKILL.md"
expect_failure "a ~/.claude path in a degrades skill is caught" check-portability.py "names '~/.claude' outside"

fresh_copy
rm "$work/repo/skills/engineering/tdd/agents/openai.yaml"
expect_failure "a portable skill without openai.yaml is caught" check-portability.py "skills/engineering/tdd: portable skill has no agents/openai.yaml"

fresh_copy
sed -i.bak '/allow_implicit_invocation/d; /^policy:/d' "$work/repo/skills/delivery/retro/agents/openai.yaml"
expect_failure "a user-invoked skill that Codex would invoke implicitly is caught" check-portability.py "retro/agents/openai.yaml: the skill is user-invoked but allow_implicit_invocation is not false"

fresh_copy
rm "$work/repo/skills/delivery/delegating-github-issues/agents/openai.yaml"
expect_failure "a claude-only skill Codex could pick on its own is caught" check-portability.py "delegating-github-issues: claude-only skill needs agents/openai.yaml"

fresh_copy
sed -i.bak 's/`adr` agent \*(Claude Code)\*/`adr` agent/g' "$work/repo/skills/delivery/ask/SKILL.md"
expect_failure "a claude-only item the router does not mark is caught" check-portability.py "ask: adr is claude-only but is never marked *(Claude Code)*"

fresh_copy
python3 - "$work/repo" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1]) / "portability.json"
d = json.loads(p.read_text())
d["claude-only"].append("no-such-skill")
p.write_text(json.dumps(d))
PY
expect_failure "a tier for an item that does not ship is caught" check-portability.py "portability.json: no-such-skill is not a shipped skill, agent or command"

fresh_copy
sed -i.bak '/skills\/writing\/wtf\/LICENSE/d' "$work/repo/ACKNOWLEDGEMENTS.md"
expect_failure "a nested LICENSE without an acknowledgement row is caught" check-licensing.py "skills/writing/wtf/LICENSE: no row in ACKNOWLEDGEMENTS.md"

fresh_copy
sed -i.bak '/Paul Hammond/d' "$work/repo/LICENSE"
expect_failure "losing Paul Hammond's notice is caught" check-licensing.py "Paul Hammond's copyright notice is missing"

fresh_copy
sed -i.bak 's/ideas only, no text copied/see above/' "$work/repo/skills/engineering/debugging/references/source-notes.md"
expect_failure "upstream source notes without a licence or ideas-only line are caught" check-licensing.py "debugging/references/source-notes.md: names an upstream repository"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
