#!/usr/bin/env bash
#
# scripts/delegate-fire decides, from GitHub state alone, whether a new
# /loop /delegate chain is needed, and starts one by POSTing to a scheduled
# task's API trigger. These tests stub the gate (delegate-status next-action
# and lease status) and curl, and check that the trigger is called only when
# there is work and a free slot, that a live chain is left to watch and land,
# that --force and --dry-run do what they say, that the project's delegation
# settings reach the gate, and that failures exit non-zero.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIRE="$REPO_ROOT/skills/delivery/delegating-github-issues/scripts/delegate-fire"
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

refuse() { # description command...
  local d="$1"
  shift
  if "$@" > /dev/null; then fail "$d"; else pass "$d"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A project checkout with delegation settings, a stub gate answering from
# $W/action and $W/lease, and a stub curl. Each stub logs its arguments.
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
| `rank_labels` | `p1`, `p2` |
| `max_worktrees` | 2 |
| `max_chains` | 3 |
| `max_open_prs` | 6 |
| `land` | on |
| `claim_ttl` | 4 hours |
EOF
  cat > "$W/bin/delegate-status" <<'EOF'
#!/usr/bin/env bash
printf '%s login=%s\n' "$*" "${DELEGATE_STATUS_LOGIN:-}" >> "$W/status.calls"
[ -f "$W/status-fails" ] && { echo "gh: HTTP 502" >&2; exit 1; }
case "$1 $2" in
  "lease status") cat "$W/lease" ;;
  "lease take")
    taken=$(($(cat "$W/taken" 2> /dev/null || echo 0) + 1))
    echo "$taken" > "$W/taken"
    if [ -f "$W/take-full-after" ] && [ "$taken" -gt "$(cat "$W/take-full-after")" ]; then
      echo '{"lease":5,"result":"full","holders":["x"],"slots":3}'; exit 5
    fi
    echo "{\"lease\":5,\"result\":\"won\",\"id\":$((700 + taken)),\"slot\":$taken,\"slots\":3}" ;;
  "ticket set")
    [ -f "$W/ticket-lost-$3" ] && { echo "{\"item\":$3,\"result\":\"lost\",\"id\":null,\"holder\":\"z\"}"; exit 4; }
    echo "{\"item\":$3,\"result\":\"set\",\"id\":$((900 + $3))}" ;;
  "lease release"|"ticket release") echo '{"result":"released"}' ;;
  next-action*) cat "$W/action" ;;
  *) echo "unexpected call: $*" >&2; exit 2 ;;
esac
EOF
  cat > "$W/bin/curl" <<'EOF'
#!/usr/bin/env bash
{ for a in "$@"; do printf '[%s] ' "$a"; done; printf '\n'; } >> "$W/curl.calls"
[ -f "$W/curl-fails" ] && { echo '{"error":"unauthorized"}'; exit 22; }
echo '{"type":"routine_fire","claude_code_session_id":"session_01abc"}'
EOF
  chmod +x "$W"/bin/*
  export W
}

fire() {
  (cd "$W/project" && PATH="$W/bin:$PATH" DELEGATE_STATUS="$W/bin/delegate-status" \
    DELEGATE_FIRE_URL="${URL-https://api.example.test/fire}" DELEGATE_FIRE_TOKEN="${TOKEN-sk-test}" \
    "$FIRE" "$@") > "$W/out" 2>&1
}

idle='{"action":"idle","reasons":["no eligible issue"],"counts":{}}'
pick='{"action":"pick","reasons":["issue #9 is eligible"],"issue":9}'
watch='{"action":"watch","reasons":["PR #20 needs review"]}'
land='{"action":"land","reasons":["PR #21 is marked ready"]}'
free='{"lease":5,"result":"status","live":1,"slots":3,"free":2,"holders":["a1b2c3d4"]}'
empty='{"lease":null,"result":"status","live":0,"slots":3,"free":3,"holders":[]}'
full='{"lease":5,"result":"status","live":3,"slots":3,"free":0,"holders":["a","b","c"]}'

# ---------------------------------------------------------------- no fire

setup
echo "$idle" > "$W/action"
echo "$free" > "$W/lease"
expect "an idle board exits 0" fire
expect "an idle board never calls the trigger" test ! -e "$W/curl.calls"
expect "the idle reason is reported" grep -q "delegate-fire: idle (no eligible issue)" "$W/out"

setup
echo "$pick" > "$W/action"
echo "$full" > "$W/lease"
expect "a full lease exits 0" fire
expect "a full lease never calls the trigger" test ! -e "$W/curl.calls"
expect "a full lease names its holders" grep -q "delegate-fire: full (a, b, c)" "$W/out"

# ---------------------------------------------------------------- fire

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
expect "pick with a free slot exits 0" fire
expect "pick with a free slot calls the trigger once" test "$(wc -l < "$W/curl.calls")" -eq 1
expect "the trigger is POSTed to the fire URL" grep -q '\[-X\] \[POST\] \[https://api.example.test/fire\]' "$W/curl.calls"
expect "the token is sent as a bearer token" grep -q '\[Authorization: Bearer sk-test\]' "$W/curl.calls"
expect "the routine beta header is sent" grep -q '\[anthropic-beta: experimental-cc-routine-2026-04-01\]' "$W/curl.calls"
expect "the API version header is sent" grep -q '\[anthropic-version: 2023-06-01\]' "$W/curl.calls"
expect "the body's text names the action and reasons" \
  grep -q '"text":"Started by delegate-fire. pick: issue #9 is eligible"' "$W/curl.calls"
expect "the fire is reported with the trigger's answer" grep -q "delegate-fire: fired (pick: issue #9 is eligible)" "$W/out"
expect "the report carries the new session id" grep -q "session_01abc" "$W/out"

calls="$(cat "$W/status.calls")"
expect "the gate reads the origin repository" grep -q -- '--repo acme/widgets' <<< "$calls"
expect "the label reaches the gate" grep -q -- '^next-action .*--label ready-for-agent' <<< "$calls"
expect "rank labels reach the gate without spaces" grep -q -- '--rank-labels p1,p2' <<< "$calls"
expect "max_worktrees reaches the gate" grep -q -- '--max-worktrees 2' <<< "$calls"
expect "max_open_prs reaches the gate" grep -q -- '--max-open-prs 6' <<< "$calls"
expect "land reaches the gate" grep -q -- '--land on' <<< "$calls"
expect "claim_ttl reaches the gate in seconds" grep -q -- '--claim-ttl 14400' <<< "$calls"
expect "max_chains reaches the lease" grep -q -- '^lease status .*--max-chains 3' <<< "$calls"
refuse "no gate call needs a session" grep -q -- '--session' <<< "$calls"

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
DELEGATE_STATUS_LOGIN=octo fire
expect "the delegator's login reaches the gate" grep -q -- '^next-action .* login=octo$' "$W/status.calls"
expect "the delegator's login reaches the lease" grep -q -- '^lease status .* login=octo$' "$W/status.calls"

WORKFLOW="$REPO_ROOT/.github/workflows/delegate-fire.yml"
expect "the reusable workflow names the delegator's login, since its token is no user" \
  grep -q 'DELEGATE_STATUS_LOGIN: ${{ inputs.delegator-login || github.repository_owner }}' "$WORKFLOW"

setup
echo "$watch" > "$W/action"
echo "$empty" > "$W/lease"
expect "watch with no live chain fires" fire
expect "watch with no live chain calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
echo "$land" > "$W/action"
echo "$empty" > "$W/lease"
expect "land with no live chain fires" fire
expect "land with no live chain calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
echo "$watch" > "$W/action"
echo "$free" > "$W/lease"
expect "watch with a live chain fires: a chain acts only on its ticket's PR" fire
expect "watch with a live chain calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
echo "$land" > "$W/action"
echo "$free" > "$W/lease"
expect "land with a live chain fires" fire
expect "land with a live chain calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

# A full lease stops new work, never finishing: the fired session's Run does
# a finish-only pass.
setup
echo "$land" > "$W/action"
echo "$full" > "$W/lease"
expect "land with a full lease fires" fire
expect "land with a full lease calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1
expect "the text says the lease is full" \
  grep -q '"text":"Started by delegate-fire. land: PR #21 is marked ready; the lease is full, so finish only"' "$W/curl.calls"

setup
echo "$watch" > "$W/action"
echo "$full" > "$W/lease"
expect "watch with a full lease fires" fire
expect "watch with a full lease calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
echo "$idle" > "$W/action"
echo "$full" > "$W/lease"
expect "--force fires on an idle board with a full lease" fire --force
expect "--force calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1
expect "--force is named in the text" grep -q 'forced' "$W/curl.calls"

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
expect "--dry-run exits 0" fire --dry-run
expect "--dry-run never calls the trigger" test ! -e "$W/curl.calls"
expect "--dry-run says it would fire" grep -q "delegate-fire: would fire (pick: issue #9 is eligible)" "$W/out"

# ---------------------------------------------------------------- reserve

picks='{"action":"pick","reasons":["issue #9 is eligible"],"issue":9,"picks":[{"number":9,"title":"a"},{"number":11,"title":"b"},{"number":12,"title":"c"}],"finish":[]}'
picks_land='{"action":"land","reasons":["PR #21 is marked ready","issue #9 is eligible"],"picks":[{"number":9,"title":"a"}],"finish":[21]}'
land_only='{"action":"land","reasons":["PR #21 is marked ready"],"picks":[],"finish":[21]}'
idle_picks='{"action":"idle","reasons":["no eligible issue"],"counts":{},"picks":[],"finish":[]}'
full_picks='{"action":"pick","reasons":["issue #9 is eligible"],"issue":9,"picks":[{"number":9,"title":"a"}],"finish":[]}'

setup
echo "$picks" > "$W/action"
echo "$free" > "$W/lease"
expect "--reserve with two free slots exits 0" fire --reserve
expect "--reserve asks the gate for picks up to max_chains" grep -q -- '^next-action .*--picks 3' "$W/status.calls"
expect "--reserve fires once per free slot" test "$(wc -l < "$W/curl.calls")" -eq 2
expect "--reserve takes a slot in each new session's name" test "$(grep -c '^lease take .*--session [0-9a-f]\{8\}' "$W/status.calls")" -eq 2
expect "--reserve sets each ticket in the session's name as its chain" \
  grep -qE '^ticket set 9 .*--session ([0-9a-f]{8}) --chain \1' "$W/status.calls"
expect "the second slot goes to the second pick" grep -q '^ticket set 11 ' "$W/status.calls"
refuse "no slot is taken beyond the free ones" grep -q '^ticket set 12 ' "$W/status.calls"
name="$(sed -n 's/^ticket set 9 .*--session \([0-9a-f]\{8\}\) .*/\1/p' "$W/status.calls")"
expect "the fire text carries a hand-off line with the session name and ticket" \
  grep -q "Delegator hand-off from delegate-fire; session name $name; ticket #9 chain $name." "$W/curl.calls"
expect "the report counts the fires" grep -q "delegate-fire: fired 2: #9 as $name (session_01abc); #11 as" "$W/out"

setup
echo "$picks" > "$W/action"
echo "$empty" > "$W/lease"
touch "$W/ticket-lost-11"
expect "a pick another chain ticketed first is skipped, not failed" fire --reserve
expect "the skipped pick's slot is released" grep -q '^lease release 702 ' "$W/status.calls"
expect "the other picks still fire" test "$(wc -l < "$W/curl.calls")" -eq 2
refuse "the skipped pick is never fired" grep -q 'ticket #11' "$W/curl.calls"

setup
echo "$picks" > "$W/action"
echo "$empty" > "$W/lease"
echo 1 > "$W/take-full-after"
expect "a lease filled by another chain stops the picks" fire --reserve
expect "only the reserved pick fires" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
echo "$picks_land" > "$W/action"
echo "$free" > "$W/lease"
expect "picks and a PR to finish exit 0" fire --reserve
expect "one more session fires to finish the PR" test "$(wc -l < "$W/curl.calls")" -eq 2
expect "the finishing session's text names the PRs" grep -q 'Started by delegate-fire to finish PRs #21' "$W/curl.calls"
refuse "the finishing session reserves nothing" grep -q '^ticket set 21' "$W/status.calls"

setup
echo "$land_only" > "$W/action"
echo "$full" > "$W/lease"
expect "a PR to finish fires on a full lease" fire --reserve
expect "only the finishing session fires" test "$(wc -l < "$W/curl.calls")" -eq 1
refuse "a full lease takes no slot" grep -q '^lease take' "$W/status.calls"

setup
echo "$full_picks" > "$W/action"
echo "$full" > "$W/lease"
expect "--reserve on a full lease exits 0" fire --reserve
expect "--reserve on a full lease never fires" test ! -e "$W/curl.calls"
expect "--reserve on a full lease names its holders" grep -q "delegate-fire: full (a, b, c)" "$W/out"

setup
echo "$idle_picks" > "$W/action"
echo "$free" > "$W/lease"
expect "--reserve on an idle board exits 0" fire --reserve
expect "--reserve on an idle board never fires" test ! -e "$W/curl.calls"

setup
echo "$picks" > "$W/action"
echo "$free" > "$W/lease"
expect "--reserve --dry-run exits 0" fire --reserve --dry-run
expect "--reserve --dry-run never fires" test ! -e "$W/curl.calls"
refuse "--reserve --dry-run reserves nothing" grep -q '^lease take' "$W/status.calls"
expect "--reserve --dry-run names the picks" grep -q "would fire a chain for each of #9, #11" "$W/out"

setup
echo "$picks" > "$W/action"
echo "$free" > "$W/lease"
touch "$W/curl-fails"
refuse "a refused fire under --reserve exits non-zero" fire --reserve
expect "a refused fire releases its ticket" grep -q '^ticket release 9 909 ' "$W/status.calls"
expect "a refused fire releases its slot" grep -q '^lease release 701 ' "$W/status.calls"
expect "every pick is still tried" grep -q '^ticket set 11 ' "$W/status.calls"
expect "the failures are reported" grep -q "failed 2: #9: the trigger refused the fire" "$W/out"

# ---------------------------------------------------------------- weekdays

weekday() { # settings day: 2026-11-14 is a Saturday, 2026-11-16 a Monday
  printf '| `weekdays_only` | on |\n' >> "$W/project/.claude/delegation.md"
}

setup
weekday
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
DELEGATE_STATUS_NOW=1794657600 expect "weekdays_only exits 0 on a Saturday" fire
expect "weekdays_only never fires on a Saturday" test ! -e "$W/curl.calls"
expect "weekdays_only never asks the gate on a Saturday" test ! -e "$W/status.calls"
expect "the weekend is reported" grep -q "delegate-fire: weekend" "$W/out"
DELEGATE_STATUS_NOW=1794657600 expect "--force fires on a Saturday" fire --force
expect "--force on a Saturday calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
weekday
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
DELEGATE_STATUS_NOW=1794830400 expect "weekdays_only fires on a Monday" fire
expect "weekdays_only on a Monday calls the trigger" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
printf '| `weekdays_only` | sometimes |\n' >> "$W/project/.claude/delegation.md"
refuse "a weekdays_only that is not on or off is refused" fire

# ---------------------------------------------------------------- outputs

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
touch "$W/summary" "$W/output"
GITHUB_STEP_SUMMARY="$W/summary" GITHUB_OUTPUT="$W/output" fire
expect "the report goes to the step summary" grep -q "delegate-fire: fired" "$W/summary"
expect "the decision goes to the step outputs" grep -qx "fired=true" "$W/output"

# ---------------------------------------------------------------- failures

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
touch "$W/status-fails"
refuse "a failed gate exits non-zero" fire
expect "a failed gate never calls the trigger" test ! -e "$W/curl.calls"

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
touch "$W/curl-fails"
refuse "a refused fire exits non-zero" fire
expect "a refused fire shows the trigger's answer" grep -q "unauthorized" "$W/out"

setup
echo "$idle" > "$W/action"
echo "$free" > "$W/lease"
URL="" refuse "a missing fire URL is refused even when idle" fire
expect "the refusal names the variable" grep -q "DELEGATE_FIRE_URL" "$W/out"
TOKEN="" refuse "a missing token is refused" fire
URL="" TOKEN="" expect "--dry-run needs no fire URL or token" fire --dry-run

setup
rm "$W/project/.claude/delegation.md"
refuse "no delegation settings is refused" fire
expect "the refusal says delegation is not set up" grep -q "no .claude/delegation.md" "$W/out"

setup
refuse "an unknown argument is refused" fire --bogus

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
