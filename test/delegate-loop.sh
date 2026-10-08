#!/usr/bin/env bash
#
# scripts/delegate-loop runs the delegation skill unattended, one fresh agent
# process per pass. These tests stub the gate (delegate-status next-action),
# the sleep and each agent CLI, and check that an idle check never calls the
# agent, that work calls it once with the rendered prompt, that STOP, the
# failure limit and the daily budget end or pause the loop, that each CLI gets
# its unattended flags, and that the project's delegation settings reach the
# gate.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOOP="$REPO_ROOT/skills/delivery/delegating-github-issues/scripts/delegate-loop"
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

expect() { # description command...
  local d="$1"
  shift
  if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A project checkout with delegation settings, and stubs for everything the
# loop calls. Each stub logs its arguments, one call per line.
setup() {
  W="$TMP/case-$RANDOM$RANDOM"
  mkdir -p "$W/bin" "$W/project/.claude"
  git init -q "$W/project"
  git -C "$W/project" remote add origin https://github.com/acme/widgets.git
  cat > "$W/project/.claude/delegation.md" <<'EOF'
# Delegation

## Parameters

| Parameter | Value |
|---|---|
| `label` | `ready-for-agent` |
| `max_worktrees` | 2 |
| `land` | on |
| `claim_ttl` | 4 hours |

## Project rules

- Run `pnpm test` before every push.
EOF
  # The gate answers from $W/actions, one JSON line per call, the last repeating.
  cat > "$W/bin/delegate-status" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$W/status.calls"
n=$(($(wc -l < "$W/status.calls")))
line="$(sed -n "${n}p" "$W/actions")"
[ -n "$line" ] || line="$(tail -n 1 "$W/actions")"
[ "$line" = FAIL ] && { echo "gh: HTTP 502" >&2; exit 1; }
printf '%s\n' "$line"
EOF
  # The sleep records its argument; after $W/sleeps-before-stop calls it stops the loop.
  cat > "$W/bin/fake-sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$W/sleep.calls"
[ "$(wc -l < "$W/sleep.calls")" -ge "$(cat "$W/sleeps-before-stop" 2> /dev/null || echo 1)" ] && touch "$W/project/.delegate-loop/STOP"
exit 0
EOF
  for cli in claude codex opencode; do
    cat > "$W/bin/$cli" <<'EOF'
#!/usr/bin/env bash
echo x >> "$W/agent.count"
{ printf '%s' "$(basename "$0")"; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\n'; } >> "$W/agent.calls"
[ -f "$W/agent-fails" ] && { echo "agent error"; exit 3; }
case "$(basename "$0")" in
  claude) echo '{"type":"result","total_cost_usd":0.42,"usage":{"input_tokens":1000,"output_tokens":200,"cache_read_input_tokens":5000}}' ;;
  codex) printf '%s\n' '{"type":"thread.started"}' '{"type":"turn.completed","usage":{"input_tokens":900,"cached_input_tokens":100,"output_tokens":50}}' ;;
  *) echo done ;;
esac
EOF
  done
  chmod +x "$W"/bin/*
  export W
}

loop() {
  (cd "$W/project" && PATH="$W/bin:$PATH" DELEGATE_STATUS="$W/bin/delegate-status" \
    DELEGATE_LOOP_SLEEP="$W/bin/fake-sleep" "$LOOP" --session test-loop "$@") > "$W/out" 2>&1
}

idle='{"action":"idle","reasons":["no eligible issue"],"counts":{}}'
pick='{"action":"pick","reasons":["issue #9 is eligible"],"issue":9}'
watch='{"action":"watch","reasons":["PR #20 needs review"]}'

# ---------------------------------------------------------------- idle

setup
echo "$idle" > "$W/actions"
expect "an idle loop exits 0 when STOP appears" loop --idle 600
expect "an idle check never starts the agent" test ! -e "$W/agent.calls"
expect "an idle check sleeps the idle interval" grep -qx 600 "$W/sleep.calls"
expect "the idle reason is logged" grep -q "idle: no eligible issue" "$W/project/.delegate-loop/loop.log"

# ---------------------------------------------------------------- work

setup
echo "$pick" > "$W/actions"
expect "a pass with work succeeds with --once" loop --once
expect "work starts the agent exactly once" test "$(wc -l < "$W/agent.count")" -eq 1
expect "claude runs headless with JSON output" grep -q '^claude \[-p\] \[--output-format\] \[json\]' "$W/agent.calls"
expect "claude never skips permissions wholesale" bash -c "! grep -q 'dangerously' '$W/agent.calls'"
expect "the prompt names the repository, session and gate" \
  grep -q 'unattended delegation loop for `acme/widgets`.*' "$W/agent.calls"
expect "the prompt carries the gate's action and reason" grep -q '\*\*pick\*\*' "$W/agent.calls"
expect "the prompt passes the session to every claim call" grep -q -- '--session test-loop' "$W/agent.calls"
expect "no placeholder is left unrendered" bash -c "! grep -q '{{' '$W/agent.calls'"
expect "the pass's usage is recorded" \
  jq -e 'select(.action == "pick" and .exit == 0 and .usage.cost_usd == 0.42 and .usage.output == 200)' "$W/project/.delegate-loop/usage.jsonl"
expect "the pass's output is kept in its scratch directory" \
  bash -c "ls '$W'/project/.delegate-loop/passes/*-pick/output.log > /dev/null"
expect "the loop's directory is excluded from commits" grep -qx '/.delegate-loop/' "$W/project/.git/info/exclude"

# The project's Parameters table reaches the gate.
calls="$(cat "$W/status.calls")"
expect "the gate is next-action for the origin repository" grep -q '^next-action --repo acme/widgets --session test-loop' <<< "$calls"
expect "the eligibility label comes from the settings" grep -q -- '--label ready-for-agent' <<< "$calls"
expect "max_worktrees comes from the settings" grep -q -- '--max-worktrees 2' <<< "$calls"
expect "land comes from the settings" grep -q -- '--land on' <<< "$calls"
expect "claim_ttl in hours becomes seconds" grep -q -- '--claim-ttl 14400' <<< "$calls"

# ---------------------------------------------------------------- other CLIs

setup
echo "$watch" > "$W/actions"
loop --once --agent codex
expect "codex runs as codex exec with JSON events" grep -q '^codex \[exec\] \[--json\]' "$W/agent.calls"
expect "codex gets a writable sandbox with network for gh" \
  grep -q '\[--sandbox\] \[workspace-write\] \[-c\] \[sandbox_workspace_write.network_access=true\]' "$W/agent.calls"
expect "codex may write the worktrees beside the checkout" grep -q "\[--add-dir\] \[$W/project-worktrees\]" "$W/agent.calls"
expect "codex usage is summed from its turn events" \
  jq -e 'select(.agent == "codex" and .usage == {"input": 900, "cached": 100, "output": 50})' "$W/project/.delegate-loop/usage.jsonl"

setup
echo "$watch" > "$W/actions"
AGENT=opencode loop --once
expect "AGENT=opencode runs opencode run" grep -q '^opencode \[run\]' "$W/agent.calls"

setup
echo "$watch" > "$W/actions"
DELEGATE_LOOP_CLAUDE_ARGS="-p --model sonnet" loop --once
expect "DELEGATE_LOOP_CLAUDE_ARGS replaces the default flags" grep -q '^claude \[-p\] \[--model\] \[sonnet\] \[' "$W/agent.calls"

# ---------------------------------------------------------------- stopping

setup
echo "$pick" > "$W/actions"
mkdir -p "$W/project/.delegate-loop" && touch "$W/project/.delegate-loop/STOP"
expect "a STOP file stops the loop before any call" loop
expect "STOP means no gate call and no agent call" test ! -e "$W/status.calls" -a ! -e "$W/agent.calls"

setup
echo "$pick" > "$W/actions"
touch "$W/agent-fails"
echo 99 > "$W/sleeps-before-stop"
if loop --max-failures 2; then fail "the failure limit exits non-zero"; else pass "the failure limit exits non-zero"; fi
expect "the failure limit stops after that many failed passes" test "$(wc -l < "$W/agent.count")" -eq 2
expect "a failed pass is logged with its exit code" grep -q "claude exited 3" "$W/project/.delegate-loop/loop.log"

setup
printf '%s\n' FAIL FAIL > "$W/actions"
echo 99 > "$W/sleeps-before-stop"
if loop --max-failures 2; then fail "a failing gate counts towards the limit"; else pass "a failing gate counts towards the limit"; fi
expect "a failing gate never starts the agent" test ! -e "$W/agent.calls"

setup
echo "$pick" > "$W/actions"
echo 2 > "$W/sleeps-before-stop"
loop --max-passes 1 --pause 5 --idle 700
expect "the daily pass budget allows that many passes" test "$(wc -l < "$W/agent.count")" -eq 1
expect "past the budget, work waits and the loop idles" grep -q "daily pass budget (1) reached" "$W/project/.delegate-loop/loop.log"
expect "after a pass the loop pauses, then idles" test "$(paste -sd, "$W/sleep.calls")" = "5,700"

# ---------------------------------------------------------------- refusals

setup
rm "$W/project/.claude/delegation.md"
echo "$pick" > "$W/actions"
if loop --once; then fail "no delegation settings is refused"; else pass "no delegation settings is refused"; fi
expect "the refusal says delegation is not set up" grep -q "no .claude/delegation.md" "$W/out"

setup
echo "$pick" > "$W/actions"
if loop --once --agent gemini; then fail "an unknown agent is refused"; else pass "an unknown agent is refused"; fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
