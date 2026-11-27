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
printf '%s %s token=%s\n' "$1" "$2" "${GH_TOKEN:-}" >> "$W/tokens"
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
  holder*)
    [ -f "$W/holder-fails" ] && { echo "gh: HTTP 502" >&2; exit 1; }
    if [ -f "$W/holder-$2" ]; then
      echo "{\"item\":$2,\"holder\":\"$(cat "$W/holder-$2")\",\"id\":5}"
    else
      echo "{\"item\":$2,\"holder\":null,\"id\":null}"
    fi ;;
  next-action*)
    if [ -f "$W/action-${DELEGATE_STATUS_LOGIN:-}" ]; then cat "$W/action-$DELEGATE_STATUS_LOGIN"; else cat "$W/action"; fi ;;
  assignees*)
    if [ -f "$W/assignees-$2" ]; then cat "$W/assignees-$2"; else echo "{\"item\":$2,\"assignees\":[],\"pr\":false}"; fi ;;
  assign*)
    to="$(printf '%s\n' "$@" | sed -n '/^--to$/{n;p;}')"
    if [ -f "$W/assign-$2" ]; then cat "$W/assign-$2"; else echo "{\"item\":$2,\"result\":\"assigned\",\"assignees\":[\"$to\"]}"; fi ;;
  unassigned*)
    if [ -f "$W/unassigned" ]; then cat "$W/unassigned"; else echo '{"issues":[]}'; fi ;;
  rereview*)
    if [ -f "$W/rereview-$2" ]; then cat "$W/rereview-$2"; else echo "{\"item\":$2,\"reviewer\":null,\"open\":[]}"; fi ;;
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
expect "the reusable workflow runs on the delegator's own events unless skip-own-events is on" \
  grep -q '!inputs.skip-own-events ||' "$WORKFLOW"
expect "skip-own-events is off by default, since the delegator usually posts as the human" \
  bash -c 'grep -A3 "      skip-own-events:" "$1" | grep -q "default: false"' _ "$WORKFLOW"

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
echo "$free" > "$W/lease"
GH_TOKEN=workflow DELEGATE_FIRE_RESERVE_TOKEN=reserver fire --reserve
expect "the gate reads with GH_TOKEN, not the reserve token" grep -q '^next-action .* token=workflow$' "$W/tokens"
expect "the lease status reads with GH_TOKEN" grep -q '^lease status token=workflow$' "$W/tokens"
expect "lease take writes with the reserve token" grep -q '^lease take token=reserver$' "$W/tokens"
expect "ticket set writes with the reserve token" grep -q '^ticket set token=reserver$' "$W/tokens"
refuse "no read uses the reserve token" grep -qE '^(next-action|lease status).* token=reserver$' "$W/tokens"

setup
echo "$picks" > "$W/action"
echo "$free" > "$W/lease"
GH_TOKEN=only fire --reserve
expect "without a reserve token, GH_TOKEN reserves too" grep -q '^lease take token=only$' "$W/tokens"

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

# A PR another session claimed between the gate's read and the fire (a
# Ready click wakes the PR's own subscribed session as it starts this
# workflow) is never fired for: the gate re-reads each PR's claim just
# before it fires, by the rule `delegate-status claim` uses.
land_claimed='{"action":"land","reasons":["PR #21 is marked ready"],"picks":[],"finish":[21]}'
watch_two='{"action":"watch","reasons":["PR #20 needs review","PR #21 is marked ready"],"picks":[],"finish":[20,21]}'
land_or_pick='{"action":"land","reasons":["PR #21 is marked ready","issue #9 is eligible"],"picks":[{"number":9,"title":"a"}],"finish":[21]}'

setup
echo "$land_claimed" > "$W/action"
echo "$free" > "$W/lease"
echo e5f6a7b8 > "$W/holder-21"
expect "a claimed PR to land exits 0" fire
expect "a claimed PR to land never fires" test ! -e "$W/curl.calls"
expect "the gate re-reads the PR's claim" grep -q '^holder 21 ' "$W/status.calls"
expect "the report names the PR and its holder" grep -q "delegate-fire: claimed (PR #21 by e5f6a7b8)" "$W/out"
expect "one fire asks the gate for the PRs it would finish" grep -q -- '^next-action .*--picks 3' "$W/status.calls"

setup
echo "$watch_two" > "$W/action"
echo "$free" > "$W/lease"
echo e5f6a7b8 > "$W/holder-21"
expect "one claimed PR of two still fires" fire
expect "it fires once" test "$(wc -l < "$W/curl.calls")" -eq 1
expect "the fire skips the claimed PR" grep -q 'skipped PR #21, claimed by e5f6a7b8' "$W/curl.calls"

setup
echo "$land_or_pick" > "$W/action"
echo "$free" > "$W/lease"
echo e5f6a7b8 > "$W/holder-21"
expect "a claimed PR with a pick and a free slot fires for the pick" fire
expect "the pick fires once" test "$(wc -l < "$W/curl.calls")" -eq 1
expect "the fire is a pick" grep -q '"text":"Started by delegate-fire. pick: issue #9 is eligible' "$W/curl.calls"

setup
echo "$land_claimed" > "$W/action"
echo "$free" > "$W/lease"
echo e5f6a7b8 > "$W/holder-21"
expect "--force fires whatever the claim" fire --force
expect "--force fires once" test "$(wc -l < "$W/curl.calls")" -eq 1

setup
echo "$land_claimed" > "$W/action"
echo "$free" > "$W/lease"
touch "$W/holder-fails"
refuse "a failed claim read exits non-zero" fire
expect "a failed claim read never fires" test ! -e "$W/curl.calls"

setup
echo "$picks_land" > "$W/action"
echo "$free" > "$W/lease"
echo e5f6a7b8 > "$W/holder-21"
expect "--reserve with a claimed PR to finish exits 0" fire --reserve
expect "--reserve fires the pick, not the claimed PR" test "$(wc -l < "$W/curl.calls")" -eq 1
refuse "--reserve starts no session to finish a claimed PR" grep -q 'to finish PRs' "$W/curl.calls"
expect "--reserve re-reads the claim just before the finishing fire" grep -q '^holder 21 ' "$W/status.calls"

setup
echo "$land_only" > "$W/action"
echo "$full" > "$W/lease"
echo e5f6a7b8 > "$W/holder-21"
expect "--reserve with only a claimed PR exits 0" fire --reserve
expect "--reserve with only a claimed PR never fires" test ! -e "$W/curl.calls"
expect "--reserve reports the claimed PR" grep -q "claimed (PR #21 by e5f6a7b8)" "$W/out"

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

# ---------------------------------------------------------------- team routing
#
# Each teammate runs the delegator under their own login with their own
# scheduled task and trigger. With a roster, one event wakes exactly one
# teammate's trigger: an issue goes to its one human assignee, or to the
# sender of the label event, who is assigned first (the assignment is the
# lock between logins); a delegated PR goes to its author; a cron run gates
# each login in turn, under strict assignee routing, after assigning each
# unassigned labelled issue to whoever labelled it.

team() { # roster line appended to the settings; triggers for alice and bob
  setup
  printf '| `roster` | `alice`, `bob` |\n' >> "$W/project/.claude/delegation.md"
  echo "$idle" > "$W/action"
  echo "$free" > "$W/lease"
}
TEAM_TRIGGERS='{"alice":{"url":"https://api.example.test/fire/alice","token":"sk-alice"},"bob":{"url":"https://api.example.test/fire/bob","token":"sk-bob"}}'
tfire() {
  (cd "$W/project" && PATH="$W/bin:$PATH" DELEGATE_STATUS="$W/bin/delegate-status" \
    DELEGATE_FIRE_TRIGGERS="${TRIGGERS-$TEAM_TRIGGERS}" GH_TOKEN=workflow \
    "$FIRE" "$@") > "$W/out" 2>&1
}
fired_for() { # login: the number of fires POSTed to that login's trigger
  grep -c "fire/$1\]" "$W/curl.calls" 2> /dev/null || true
}
labeled() { # number sender [label]
  tfire --event issues --action labeled --label "${3:-ready-for-agent}" --number "$1" --sender "$2"
}

team
echo "$pick" > "$W/action-alice"
expect "a label event on an unassigned issue exits 0" labeled 9 alice
expect "the sender is assigned first" grep -q '^assign 9 .*--to alice' "$W/status.calls"
expect "only the sender's trigger fires" test "$(fired_for alice)" -eq 1 -a "$(fired_for bob)" -eq 0
expect "the fire carries the sender's token" grep -q '\[Authorization: Bearer sk-alice\]' "$W/curl.calls"
expect "the gate runs as the sender" grep -q '^next-action .* login=alice$' "$W/status.calls"
refuse "the gate never runs as anyone else" grep -q '^next-action .* login=bob$' "$W/status.calls"
expect "a roster gate uses strict assignee routing" grep -q '^next-action .*--assignee-routing strict' "$W/status.calls"
expect "the assignment is reported" grep -q 'delegate-fire: #9: assigned to alice (labelled by alice)' "$W/out"
expect "the sender's line says it fired" grep -q 'delegate-fire: alice: fired (pick: issue #9 is eligible)' "$W/out"

team
echo "$pick" > "$W/action-bob"
echo '{"item":9,"assignees":["bob"],"pr":false}' > "$W/assignees-9"
expect "a label event on an issue assigned to bob exits 0" labeled 9 alice
expect "only bob's trigger fires" test "$(fired_for bob)" -eq 1 -a "$(fired_for alice)" -eq 0
refuse "an assigned issue is not assigned again" grep -q '^assign ' "$W/status.calls"

team
echo "$pick" > "$W/action"
echo '{"item":9,"assignees":["alice","bob"],"pr":false}' > "$W/assignees-9"
expect "several assignees exit 0" labeled 9 alice
expect "several assignees fire nothing" test ! -e "$W/curl.calls"
expect "several assignees say why" grep -q 'delegate-fire: #9: ambiguous assignees (alice, bob)' "$W/out"
refuse "several assignees run no gate" grep -q '^next-action' "$W/status.calls"

team
echo "$pick" > "$W/action"
echo '{"item":9,"assignees":["carol"],"pr":false}' > "$W/assignees-9"
expect "an owner not on the roster exits 0" labeled 9 alice
expect "an owner not on the roster fires nothing" test ! -e "$W/curl.calls"
expect "an owner not on the roster is named" grep -q 'delegate-fire: #9: assigned to carol, who is not on the roster' "$W/out"

team
echo "$pick" > "$W/action"
expect "a sender not on the roster exits 0" labeled 9 carol
expect "a sender not on the roster fires nothing" test ! -e "$W/curl.calls"
refuse "a sender not on the roster is not assigned" grep -q '^assign ' "$W/status.calls"
expect "a sender not on the roster is named" grep -q 'delegate-fire: #9: labelled by carol, who is not on the roster' "$W/out"

team
echo "$pick" > "$W/action"
expect "another label exits 0" labeled 9 alice in-progress
expect "another label fires nothing" test ! -e "$W/curl.calls"
refuse "another label reads nothing" grep -q '^assignees' "$W/status.calls"
expect "another label is reported" grep -q 'delegate-fire: ignored (label in-progress is not ready-for-agent)' "$W/out"

team
echo "$pick" > "$W/action"
echo '{"item":9,"result":"assigned","assignees":["alice","bob"]}' > "$W/assign-9"
expect "an assignment that finds another human exits 0" labeled 9 alice
expect "an assignment that finds another human fires nothing" test ! -e "$W/curl.calls"
expect "it says why" grep -q 'delegate-fire: #9: ambiguous assignees (alice, bob)' "$W/out"

team
echo "$pick" > "$W/action-alice"
expect "--dry-run on a label event exits 0" tfire --dry-run --event issues --action labeled --label ready-for-agent --number 9 --sender alice
expect "--dry-run assigns nobody" bash -c '! grep -q "^assign " "$1"' _ "$W/status.calls"
expect "--dry-run fires nothing" test ! -e "$W/curl.calls"
expect "--dry-run says whom it would assign" grep -q 'delegate-fire: #9: would assign to alice (labelled by alice)' "$W/out"
expect "--dry-run previews the gate with the issue as the sender's" grep -q '^next-action .*--as-assigned 9 .*login=alice$' "$W/status.calls"
expect "--dry-run reports the sender's decision" grep -q 'delegate-fire: alice: would fire (pick: issue #9 is eligible)' "$W/out"

# Pull request events go to the PR's author.
pr_event() { # event action number author head
  tfire --event "$1" --action "$2" --number "$3" --author "$4" --head "$5"
}
team
echo "$land" > "$W/action-alice"
expect "a Ready event on alice's delegated PR exits 0" pr_event pull_request ready_for_review 21 alice delegated/9-thing
expect "only alice's trigger fires" test "$(fired_for alice)" -eq 1 -a "$(fired_for bob)" -eq 0

team
echo "$land_claimed" > "$W/action-alice"
echo e5f6a7b8 > "$W/holder-21"
expect "a Ready event on a PR another session holds exits 0" pr_event pull_request ready_for_review 21 alice delegated/9-thing
expect "a Ready event on a held PR fires nothing" test ! -e "$W/curl.calls"
expect "the holder is re-read" grep -q '^holder 21 ' "$W/status.calls"
expect "alice's line names the claim" grep -q 'delegate-fire: alice: claimed (PR #21 by e5f6a7b8)' "$W/out"

team
echo "$watch" > "$W/action-bob"
expect "a review on bob's delegated PR exits 0" pr_event pull_request_review submitted 20 bob delegated/7-x
expect "only bob's trigger fires for his review" test "$(fired_for bob)" -eq 1 -a "$(fired_for alice)" -eq 0

team
echo "$land" > "$W/action"
expect "a PR that is not delegated exits 0" pr_event pull_request ready_for_review 30 alice feature/x
expect "a PR that is not delegated fires nothing" test ! -e "$W/curl.calls"
expect "a PR that is not delegated is reported" grep -q 'delegate-fire: ignored (PR #30 is not a delegated PR)' "$W/out"

team
echo "$land" > "$W/action"
expect "a PR by someone off the roster exits 0" pr_event pull_request closed 21 carol delegated/9-thing
expect "a PR by someone off the roster fires nothing" test ! -e "$W/curl.calls"
expect "its author is named" grep -q 'delegate-fire: PR #21: opened by carol, who is not on the roster' "$W/out"

# A cron run gates each login, after routing unassigned issues.
team
echo "$pick" > "$W/action-alice"
echo '{"action":"pick","reasons":["issue #12 is eligible"],"issue":12}' > "$W/action-bob"
echo '{"issues":[{"number":12,"title":"a","labeller":"bob"},{"number":13,"title":"b","labeller":"carol"},{"number":14,"title":"c","labeller":null}]}' > "$W/unassigned"
expect "a cron run exits 0" tfire --event schedule
expect "an unassigned issue goes to its labeller" grep -q '^assign 12 .*--to bob' "$W/status.calls"
refuse "an issue labelled off the roster is not assigned" grep -q '^assign 13 ' "$W/status.calls"
refuse "an issue with no labeled event is not assigned" grep -q '^assign 14 ' "$W/status.calls"
expect "the labeller's assignment is reported" grep -q 'delegate-fire: #12: assigned to bob (labelled by bob)' "$W/out"
expect "an issue labelled off the roster is reported" grep -q 'delegate-fire: #13: skipped (labelled by carol, who is not on the roster)' "$W/out"
expect "an issue with no labeled event is reported" grep -q 'delegate-fire: #14: skipped (no labeled event)' "$W/out"
expect "each login is gated as itself" bash -c 'grep -q "^next-action .* login=alice$" "$1" && grep -q "^next-action .* login=bob$" "$1"' _ "$W/status.calls"
expect "each login's lease is read as itself" grep -q '^lease status .*--assignee-routing strict.* login=bob$' "$W/status.calls"
expect "each login fires its own trigger once" test "$(fired_for alice)" -eq 1 -a "$(fired_for bob)" -eq 1
expect "bob's fire is for his issue" grep -q 'fire/bob\].*issue #12' "$W/curl.calls"
expect "one line per login" bash -c 'grep -q "delegate-fire: alice: fired" "$1" && grep -q "delegate-fire: bob: fired" "$1"' _ "$W/out"

team
echo "$pick" > "$W/action-alice"
echo "$pick" > "$W/action-bob"
echo '{"lease":5,"result":"status","live":2,"slots":3,"free":1,"holders":["a","b"]}' > "$W/lease"
expect "a cron run with one free slot exits 0" tfire --event schedule
expect "one free slot fires one pick" test "$(wc -l < "$W/curl.calls")" -eq 1
expect "the second login is full" grep -q 'delegate-fire: bob: full' "$W/out"

team
printf '| `max_chains_per_login` | 1 |\n' >> "$W/project/.claude/delegation.md"
echo "$pick" > "$W/action-alice"
echo "$pick" > "$W/action-bob"
echo '{"lease":5,"result":"status","live":1,"slots":3,"free":2,"holders":["a1"],"by_login":{"alice":1}}' > "$W/lease"
expect "a cron run with max_chains_per_login exits 0" tfire --event schedule
expect "a login at its cap is not fired a pick" test "$(fired_for alice)" -eq 0
expect "a login under its cap fires" test "$(fired_for bob)" -eq 1
expect "the cap is reported" grep -q 'delegate-fire: alice: cap (1/1)' "$W/out"

team
printf '| `max_chains_per_login` | 1 |\n' >> "$W/project/.claude/delegation.md"
echo "$land" > "$W/action-alice"
echo '{"lease":5,"result":"status","live":1,"slots":3,"free":2,"holders":["a1"],"by_login":{"alice":1}}' > "$W/lease"
expect "a login at its cap still finishes" tfire --event schedule
expect "its land fires" test "$(fired_for alice)" -eq 1

team
echo "$pick" > "$W/action-alice"
echo '{"issues":[{"number":12,"title":"a","labeller":"bob"}]}' > "$W/unassigned"
expect "a cron --dry-run exits 0" tfire --event schedule --dry-run
refuse "a cron --dry-run assigns nobody" grep -q '^assign ' "$W/status.calls"
expect "a cron --dry-run fires nothing" test ! -e "$W/curl.calls"
expect "a cron --dry-run says whom it would assign" grep -q 'delegate-fire: #12: would assign to bob (labelled by bob)' "$W/out"
expect "a cron --dry-run previews bob's gate with the issue as his" grep -q '^next-action .*--as-assigned 12 .*login=bob$' "$W/status.calls"
expect "a cron --dry-run reports each login" bash -c 'grep -q "delegate-fire: alice: would fire" "$1" && grep -q "delegate-fire: bob: idle" "$1"' _ "$W/out"
TRIGGERS="" expect "a cron --dry-run needs no triggers" tfire --event schedule --dry-run

team
echo "$pick" > "$W/action-alice"
echo "$pick" > "$W/action-bob"
TRIGGERS='{"alice":{"url":"https://api.example.test/fire/alice","token":"sk-alice"}}' \
  expect "a login with no trigger exits 0" tfire --event schedule
expect "a login with no trigger is never fired" test "$(fired_for bob)" -eq 0
expect "a login with no trigger is reported" grep -q 'delegate-fire: bob: no trigger' "$W/out"
expect "the other login still fires" test "$(fired_for alice)" -eq 1

team
echo "$picks" > "$W/action-alice"
echo "$pick" > "$W/action-bob"
echo "$empty" > "$W/lease"
TRIGGERS='{"alice":{"url":"https://api.example.test/fire/alice","token":"sk-alice","reserve_token":"rt-alice"},"bob":{"url":"https://api.example.test/fire/bob","token":"sk-bob"}}' \
  expect "a cron run with one reserve token exits 0" tfire --event schedule
expect "alice reserves with her own token" grep -q '^lease take token=rt-alice$' "$W/tokens"
expect "alice's reservations are hers" grep -q '^lease take .* login=alice$' "$W/status.calls"
expect "alice fills a slot per pick" test "$(fired_for alice)" -eq 3
expect "bob, without a reserve token, fires once" test "$(fired_for bob)" -eq 1
refuse "bob never reserves" grep -q '^lease take .* login=bob$' "$W/status.calls"

team
echo "$pick" > "$W/action"
TRIGGERS="" refuse "a roster without triggers is refused" tfire --event schedule
expect "the refusal names the variable" grep -q 'DELEGATE_FIRE_TRIGGERS' "$W/out"
TRIGGERS="not json" refuse "triggers that are not JSON are refused" tfire --event schedule

team
touch "$W/summary" "$W/output"
echo "$pick" > "$W/action-alice"
(export GITHUB_STEP_SUMMARY="$W/summary" GITHUB_OUTPUT="$W/output"; tfire --event schedule)
expect "each login's line goes to the step summary" bash -c 'grep -q "delegate-fire: alice: fired" "$1" && grep -q "delegate-fire: bob: idle" "$1"' _ "$W/summary"
expect "fired=true when any login fired" grep -qx "fired=true" "$W/output"

setup
printf '| `assignee_routing` | on |\n' >> "$W/project/.claude/delegation.md"
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
fire
expect "assignee_routing reaches a single-login gate" grep -q -- '^next-action .*--assignee-routing on' "$W/status.calls"

setup
echo "$pick" > "$W/action"
echo "$free" > "$W/lease"
fire --event issues --action labeled --label ready-for-agent --number 9 --sender alice
expect "without a roster, events change nothing" grep -q "delegate-fire: fired (pick: issue #9 is eligible)" "$W/out"
refuse "without a roster, nobody is assigned" grep -q '^assign' "$W/status.calls"
refuse "without a roster, the gate uses no routing" grep -q -- '--assignee-routing' "$W/status.calls"

setup
printf '| `assignee_routing` | sometimes |\n' >> "$W/project/.claude/delegation.md"
refuse "an assignee_routing that is not off, on or strict is refused" fire

expect "the reusable workflow takes the triggers secret" grep -q '      triggers:' "$WORKFLOW"
expect "the reusable workflow passes the triggers to the script" grep -q 'DELEGATE_FIRE_TRIGGERS: ${{ secrets.triggers }}' "$WORKFLOW"
expect "the routing inputs come from the event context" grep -q 'EVENT: ${{ github.event_name }}' "$WORKFLOW"
expect "the label event's label reaches the script" grep -q 'LABEL: ${{ github.event.label.name }}' "$WORKFLOW"
expect "the PR's author reaches the script" grep -q 'AUTHOR: ${{ github.event.pull_request.user.login }}' "$WORKFLOW"
expect "the PR's branch reaches the script" grep -q 'HEAD_REF: ${{ github.event.pull_request.head.ref }}' "$WORKFLOW"
expect "the called job takes the caller's permissions, so a read-only single-login caller still works" \
  bash -c '! grep -q "^    permissions:" "$1"' _ "$WORKFLOW"
expect "fire-url and fire-token are still taken" bash -c 'grep -q "      fire-url:" "$1" && grep -q "      fire-token:" "$1"' _ "$WORKFLOW"

# A review_requested event on a delegated PR wakes the requested reviewer's
# review-requests trigger for a re-review, with rereview on: only when their
# latest submitted review-requests review was of an older head and still has
# an open blocking or should-fix thread, so a round that leaves none open
# ends the exchange.
REVIEW_TRIGGERS='{"alice":{"url":"https://api.example.test/fire/alice","token":"sk-alice"},"bob":{"url":"https://api.example.test/fire/bob","token":"sk-bob","review_url":"https://api.example.test/review/bob","review_token":"sk-bob-review"}}'
rr_team() {
  team
  printf '| `rereview` | on |\n' >> "$W/project/.claude/delegation.md"
  echo '{"item":21,"head":"h2","author":"alice","reviewer":"bob","review_id":801,"reviewed_head":"h1","open":[900,902]}' > "$W/rereview-21"
}
requested() { # reviewer [author] [head]
  TRIGGERS="${TRIGGERS-$REVIEW_TRIGGERS}" tfire --event pull_request --action review_requested --number 21 \
    --author "${2:-alice}" --head "${3:-delegated/9-thing}" --reviewer "$1"
}
reviews_fired() { grep -c 'review/bob\]' "$W/curl.calls" 2> /dev/null || true; }

rr_team
expect "a re-review request exits 0" requested bob
expect "the reviewer's review trigger fires once" test "$(reviews_fired)" -eq 1
expect "no delegator trigger fires for it" test "$(fired_for alice)" -eq 0 -a "$(fired_for bob)" -eq 0
expect "the fire carries the review token" grep -q '\[Authorization: Bearer sk-bob-review\]' "$W/curl.calls"
expect "the fire names the PR for review-requests" grep -q '/review-requests acme/widgets#21' "$W/curl.calls"
expect "the reviewer's line says it fired" grep -q 'delegate-fire: bob: fired a re-review of PR #21 (2 open threads)' "$W/out"
refuse "a re-review request runs no delegator gate" grep -q '^next-action' "$W/status.calls"

rr_team
printf '| `rereview_command` | /craft:review-requests |\n' >> "$W/project/.claude/delegation.md"
requested bob
expect "rereview_command sets the fire's text" grep -q '/craft:review-requests acme/widgets#21' "$W/curl.calls"

team
echo '{"item":21,"head":"h2","author":"alice","reviewer":"bob","reviewed_head":"h1","open":[900]}' > "$W/rereview-21"
expect "with rereview off a request exits 0" requested bob
expect "with rereview off nothing fires" test ! -e "$W/curl.calls"
expect "with rereview off it says so" grep -q 'ignored (pull_request.review_requested; rereview is off)' "$W/out"

rr_team
echo '{"item":21,"head":"h2","author":"alice","reviewer":"bob","reviewed_head":"h1","open":[]}' > "$W/rereview-21"
expect "nothing open exits 0" requested bob
expect "nothing open fires nothing: the exchange ends" test ! -e "$W/curl.calls"
expect "nothing open says why" grep -q 'bob: nothing to re-review on PR #21 (no open blocking or should fix thread)' "$W/out"

rr_team
echo '{"item":21,"head":"h2","author":"alice","reviewer":"bob","reviewed_head":"h2","open":[900]}' > "$W/rereview-21"
requested bob
expect "a head already reviewed fires nothing" test ! -e "$W/curl.calls"
expect "a head already reviewed says so" grep -q 'bob: PR #21 is already reviewed at h2' "$W/out"

rr_team
echo '{"item":21,"head":"h2","author":"alice","reviewer":"carol","reviewed_head":"h1","open":[900]}' > "$W/rereview-21"
requested bob
expect "a first request of a reviewer fires nothing" test ! -e "$W/curl.calls"
expect "a first request is not a re-review" grep -q 'bob: PR #21 has no review-requests review of theirs to follow up; not a re-review' "$W/out"

rr_team
requested alice bob
expect "a reviewer with no review trigger fires nothing" test ! -e "$W/curl.calls"
expect "a reviewer with no review trigger is named" grep -q 'alice: no review trigger (PR #21 waits in their review queue)' "$W/out"
refuse "a reviewer with no review trigger reads nothing" grep -q '^rereview' "$W/status.calls"

rr_team
requested carol
expect "a reviewer off the roster fires nothing" test ! -e "$W/curl.calls"
expect "a reviewer off the roster is named" grep -q 'PR #21: review requested from carol, who is not on the roster' "$W/out"

rr_team
requested bob bob
expect "a request of the PR's own author fires nothing" test ! -e "$W/curl.calls"

rr_team
requested bob alice feature/x
expect "a request on a PR that is not delegated fires nothing" test ! -e "$W/curl.calls"

rr_team
TRIGGERS="" expect "a re-review --dry-run needs no triggers" \
  tfire --dry-run --event pull_request --action review_requested --number 21 --author alice --head delegated/9-thing --reviewer bob
expect "a re-review --dry-run fires nothing" test ! -e "$W/curl.calls"
expect "a re-review --dry-run says it would fire" grep -q 'bob: would fire a re-review of PR #21 (2 open threads)' "$W/out"

rr_team
touch "$W/curl-fails"
refuse "a refused review fire exits non-zero" requested bob
expect "a refused review fire says so" grep -q 'bob: failed: the review trigger refused the fire' "$W/out"

setup
printf '| `rereview` | sometimes |\n' >> "$W/project/.claude/delegation.md"
refuse "a rereview that is not on or off is refused" fire

expect "the reusable workflow passes the requested reviewer" grep -q 'REVIEWER: ${{ github.event.requested_reviewer.login }}' "$WORKFLOW"
expect "the reusable workflow hands --reviewer to the script" grep -q -- '--reviewer "$REVIEWER"' "$WORKFLOW"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
