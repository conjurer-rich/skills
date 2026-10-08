#!/usr/bin/env bash
#
# scripts/skill-usage.py counts how often each craft skill, agent and command
# was used in local Claude Code transcripts, for the triage step of
# the shelf triage (PROVENANCE.md). This test feeds it a fixed set of
# transcripts and a fixed plugin tree and checks the counts it reports.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
USAGE="$REPO_ROOT/scripts/skill-usage.py"
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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A plugin with five skills, one agent and one command. The used `tdd` routes
# to `testing` and the unused `helper`; only the unused `unused` routes to
# `lonely`; CLAUDE.md routes to `unused`.
plugin="$work/plugin"
mkdir -p "$plugin/skills/tdd" "$plugin/skills/testing" "$plugin/skills/unused" \
  "$plugin/skills/helper" "$plugin/skills/lonely" "$plugin/agents" "$plugin/commands"
printf -- '---\nname: tdd\n---\nLoad the `testing` skill, then `craft:helper`.\n' > "$plugin/skills/tdd/SKILL.md"
printf -- '---\nname: helper\n---\nHelp.\n' > "$plugin/skills/helper/SKILL.md"
printf -- '---\nname: lonely\n---\nAlone.\n' > "$plugin/skills/lonely/SKILL.md"
printf -- 'For anything, load `unused`.\n' > "$plugin/CLAUDE.md"
printf -- '---\nname: testing\n---\nTesting.\n' > "$plugin/skills/testing/SKILL.md"
printf -- '---\nname: unused\n---\nSee `lonely`.\n' > "$plugin/skills/unused/SKILL.md"
printf -- '---\nname: tdd-guardian\n---\nGuard.\n' > "$plugin/agents/tdd-guardian.md"
printf -- 'Delegate.\n' > "$plugin/commands/delegate.md"

now="$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
old="2020-01-01T00:00:00Z"

projects="$work/projects"
mkdir -p "$projects/-repo-a/session-1/subagents" "$projects/-repo-b"

skill_call() { # timestamp session skill
  printf '{"type":"assistant","timestamp":"%s","sessionId":"%s","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"%s"}}]}}\n' "$1" "$2" "$3"
}
agent_call() { # timestamp session subagent_type
  printf '{"type":"assistant","timestamp":"%s","sessionId":"%s","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"%s","prompt":"x"}}]}}\n' "$1" "$2" "$3"
}
command_turn() { # timestamp session command
  printf '{"type":"user","timestamp":"%s","sessionId":"%s","message":{"content":"<command-name>%s</command-name>"}}\n' "$1" "$2" "$3"
}

{
  skill_call "$now" s1 "craft:tdd"
  skill_call "$now" s1 "craft:tdd"
  skill_call "$old" s1 "craft:tdd"          # outside the window
  agent_call "$now" s1 "craft:tdd-guardian"
  command_turn "$now" s1 "/craft:delegate"
  printf 'not json\n'                        # a torn line is skipped
} > "$projects/-repo-a/s1.jsonl"
# A subagent's own transcript, nested under the session directory.
skill_call "$now" s1 "testing" > "$projects/-repo-a/session-1/subagents/agent-1.jsonl"
{
  skill_call "$now" s2 "tdd"                 # bare name, e.g. a ~/.claude/skills copy
  skill_call "$now" s2 "grill-me"            # not in the plugin
  command_turn "$now" s2 "/delegate"
} > "$projects/-repo-b/s2.jsonl"

json="$(python3 "$USAGE" --projects "$projects" --plugin-root "$plugin" --days 90 --format json)"

check() { # description python-expression-over-`r`
  if python3 -c "import json,sys; r=json.loads(sys.argv[1]); sys.exit(0 if ($2) else 1)" "$json"; then
    pass "$1"
  else
    fail "$1"
  fi
}

item='(lambda k, n: next(i for i in r["items"] if i["kind"] == k and i["name"] == n))'

check "tdd counts prefixed and bare calls inside the window" "$item('skill','tdd')['uses'] == 3"
check "tdd is seen in two sessions" "$item('skill','tdd')['sessions'] == 2"
check "a subagent transcript counts" "$item('skill','testing')['uses'] == 1"
check "testing is routed to by tdd" "$item('skill','testing')['routed_by'] == ['tdd']"
check "an unused skill routed to only by CLAUDE.md is a Drop candidate" "$item('skill','unused')['suggest'] == 'drop?'"
check "CLAUDE.md routing is still shown" "$item('skill','unused')['routed_by'] == ['CLAUDE.md']"
check "an unused skill a used skill routes to needs review" "$item('skill','helper')['suggest'] == 'review'"
check "an unused skill routed to only by an unused skill is a Drop candidate" "$item('skill','lonely')['suggest'] == 'drop?'"
check "a used skill is suggested Own" "$item('skill','tdd')['suggest'] == 'own'"
check "an agent spawn counts" "$item('agent','tdd-guardian')['uses'] == 1"
check "prefixed and bare slash commands count" "$item('command','delegate')['uses'] == 2"
check "a skill outside the plugin is listed separately" "r['other'].get('skill:grill-me') == 1"
check "transcript files read are reported" "r['files'] == 3"

md="$(python3 "$USAGE" --projects "$projects" --plugin-root "$plugin" --days 90)"
if grep -q '| skill | unused | 0 |' <<< "$md"; then
  pass "the default Markdown table lists zero-use items"
else
  fail "the default Markdown table lists zero-use items"
fi

check "the earliest record in the window is reported" "r['earliest'] is not None and r['earliest'] != '2020-01-01'"

python3 "$USAGE" --projects "$projects" --plugin-root "$plugin" --output "$work/out.md"
if python3 -c "import sys; open(sys.argv[1], encoding='utf-8', errors='strict').read()" "$work/out.md" \
  && grep -q '^| skill | tdd | 3 |' "$work/out.md"; then
  pass "--output writes the report as UTF-8"
else
  fail "--output writes the report as UTF-8"
fi

# The bucketed layout: skills/<bucket>/<name>/, with shelf/ for items that
# are kept but not shipped, and deprecated aliases left out.
bucketed="$work/bucketed"
mkdir -p "$bucketed/skills/engineering/tdd" "$bucketed/skills/deprecated/old-alias" \
  "$bucketed/shelf/skills/lonely" "$bucketed/agents" "$bucketed/shelf/agents" "$bucketed/commands"
printf -- '---\nname: tdd\n---\nTDD.\n' > "$bucketed/skills/engineering/tdd/SKILL.md"
printf -- '---\nname: old-alias\n---\nAlias.\n' > "$bucketed/skills/deprecated/old-alias/SKILL.md"
printf -- '---\nname: lonely\n---\nAlone.\n' > "$bucketed/shelf/skills/lonely/SKILL.md"
printf -- 'Guard.\n' > "$bucketed/agents/tdd-guardian.md"
printf -- 'Old.\n' > "$bucketed/shelf/agents/ts-enforcer.md"
json="$(python3 "$USAGE" --projects "$projects" --plugin-root "$bucketed" --format json)"
check "a bucketed skill is found and counted" "$item('skill','tdd')['uses'] == 3 and $item('skill','tdd')['shipped']"
check "a shelved skill is listed as not shipped" "$item('skill','lonely')['shipped'] is False"
check "a shelved agent is listed as not shipped" "$item('agent','ts-enforcer')['shipped'] is False"
check "a deprecated alias is left out" "not any(i['name'] == 'old-alias' for i in r['items'])"

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES skill-usage check(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All skill-usage checks passed${NC}"
