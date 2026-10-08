#!/usr/bin/env bash
#
# Test the delegating-github-issues bookkeeping script against recorded gh
# REST JSON. A fake gh and git (test/fixtures/delegate-status/bin) serve the
# fixtures, apply writes to the recorded comments, and log every call, so a
# test can check both what the script printed and what it wrote to GitHub.
#
# Claude Code on the web blocks GitHub GraphQL, so the script reaches GitHub
# through `gh api` REST calls only, plus the session proxy's /ccr/ routes for
# review threads and draft state; these tests pin that, and the GraphQL
# fallback the CLI takes when a /ccr/ route answers 404.
#
# Covers the races the Claims protocol exists for (two claims at once, a
# lapsed claim with the lower id, renewing a lapsed claim, a stale progress
# label), squash-merged worktree reclaim, the needs-an-answer rules (marker,
# Claude Code footer, [bot] and Bot authors, preview stickies, reply-to), PR
# classification, Land markers and the Pick skip cache.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUS="$REPO_ROOT/skills/delivery/delegating-github-issues/scripts/delegate-status"
FIXTURES="$SCRIPT_DIR/fixtures/delegate-status"
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

# 2026-10-02T12:00:00Z
NOW=1790942400
OURS=a1b2c3d4
OTHER=e5f6a7b8

# Fresh copy of a scenario, so writes from one test never leak into the next.
use() {
  export FAKE_STATE="$TMP/$1-$RANDOM$RANDOM"
  cp -R "$FIXTURES/$1" "$FAKE_STATE"
  : > "$FAKE_STATE/calls.log"
}

run() {
  PATH="$FIXTURES/bin:$PATH" DELEGATE_STATUS_NOW="${RUN_NOW:-$NOW}" "$STATUS" "$@" \
    --repo acme/widgets --session "$OURS" --claim-ttl 14400
}

# check <label> <json> <jq expression that must be true>
check() {
  local label="$1" json="$2" expr="$3"

  if printf '%s' "$json" | jq -e "$expr" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
    printf '      got: %s\n' "$(printf '%s' "$json" | head -c 600)"
  fi
}

called() {
  grep -Fq -- "$1" "$FAKE_STATE/calls.log"
}

check_called() {
  if called "$1"; then pass "$2"; else fail "$2"; fi
}

check_not_called() {
  if called "$1"; then fail "$2"; else pass "$2"; fi
}

if [ ! -x "$STATUS" ]; then
  fail "scripts/delegate-status exists and is executable"
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

# ---------------------------------------------------------------- usage

if PATH="$FIXTURES/bin:$PATH" "$STATUS" > /dev/null 2>&1; then
  fail "no command is a usage error"
else
  pass "no command is a usage error"
fi
if PATH="$FIXTURES/bin:$PATH" "$STATUS" status > /dev/null 2>&1; then
  fail "status without --repo is a usage error"
else
  pass "status without --repo is a usage error"
fi

# ---------------------------------------------------------------- claim

# Two sessions claimed issue 7 at once: theirs has the lower id, so they win
# and we withdraw ours.
use claims
out="$(run claim 7)"
check "a claim that loses the race reports lost and the holder" "$out" \
  '.result == "lost" and .item == 7 and .holder == "'"$OTHER"'"'
check_called "-X DELETE repos/acme/widgets/issues/comments/900" "the losing session deletes its own claim"
check_not_called "-X DELETE repos/acme/widgets/issues/comments/100" "the losing session leaves the winner's claim alone"
check_not_called "issues/7/labels" "the losing session adds no label"

# A lapsed claim keeps its lower id but no longer counts.
use claims
out="$(run claim 8)"
check "a claim beats a lapsed claim with a lower id" "$out" '.result == "won" and .id == 900'
check_called "-X POST repos/acme/widgets/issues/8/labels -f labels[]=in-progress" "a winning claim adds the progress label"
check_not_called "comments/200" "a lapsed claim of another session is not touched"

# Holding a live claim already: use it, post nothing new.
use claims
out="$(run claim 9)"
check "a live claim of our own is reused" "$out" '.result == "won" and .id == 300'
check_not_called "-X POST repos/acme/widgets/issues/9/comments" "no second claim is posted"

# The label is created when the repository lacks it, never with --force.
use claims
echo '[]' > "$FAKE_STATE/labels.json"
run claim 8 > /dev/null
check_called "api -X POST repos/acme/widgets/labels -f name=in-progress" "a missing progress label is created"
check_not_called "--force" "the label is never created with --force"

# An open delegated PR for the issue is reported on a won claim.
use claims
out="$(run claim 12)"
check "a won claim names an open delegated PR for the issue" "$out" '.result == "won" and .open_pr == 40'

# ---------------------------------------------------------------- confirm and renew

use claims
check "confirm: our live, lowest claim is live" "$(run confirm 9 300)" '.result == "live"'
check "confirm: a claim outranked by a lower live claim is lost" "$(run confirm 7 99)" '.result == "lost"'
check "confirm: a lapsed claim is lost" "$(run confirm 10 400)" '.result == "lost" and .holder == "'"$OTHER"'"'

use claims
out="$(run renew 10 400)"
check "renew refuses a lapsed claim another session has since outranked" "$out" '.result == "lost"'
check_not_called "-X PATCH" "renewing a lapsed claim writes nothing"

use claims
out="$(run renew 9 300)"
check "renew rewrites a live claim" "$out" '.result == "renewed" and .id == 300'
body="$(jq -r '.[] | select(.id == 300) | .body' "$FAKE_STATE/comments-9.json")"
check "the renewed claim's first line ends with the renewal time" "$(jq -n --arg b "$body" '$b')" \
  '(split("\n")[0] | endswith("renewed 2026-10-02T12:00:00Z")) and (split("\n")[1] == "<!-- delegator claim: '"$OURS"' -->")'
run renew 9 300 > /dev/null
body="$(jq -r '.[] | select(.id == 300) | .body' "$FAKE_STATE/comments-9.json")"
check "a second renewal replaces the first timestamp" "$(jq -n --arg b "$body" '$b')" \
  '(split("\n")[0] | [scan("renewed")] | length) == 1'

# ---------------------------------------------------------------- release

use claims
out="$(run release 9 300 --reason 'PR opened')"
check "release reports released" "$out" '.result == "released"'
check_called "-X DELETE repos/acme/widgets/issues/9/labels/in-progress" "release removes the label first"
body="$(jq -r '.[] | select(.id == 300) | .body' "$FAKE_STATE/comments-9.json")"
check "release rewrites the claim as released" "$(jq -n --arg b "$body" '$b')" \
  '. == "Released by delegator session `'"$OURS"'`: PR opened.\n<!-- delegator claim-released: '"$OURS"' -->"'

use claims
run release 9 300 --delete > /dev/null
check "release --delete deletes the claim" "$(cat "$FAKE_STATE/comments-9.json")" 'all(.[]; .id != 300)'

use claims
touch "$FAKE_STATE/labels-404"
check "a label already gone does not fail the release" "$(run release 9 300 --delete)" '.result == "released"'

use claims
if run release 11 500 --delete > /dev/null 2>&1; then
  fail "release refuses another session's claim"
else
  pass "release refuses another session's claim"
fi
check_not_called "-X DELETE repos/acme/widgets/issues/comments/500" "another session's claim is never deleted"
check_not_called "-X DELETE repos/acme/widgets/issues/11/labels" "another session's label is never removed"

# Release touches only the item it names, and leaves the label to a session
# that has since won the item.
use claims
if run release 11 300 --delete > /dev/null 2>&1; then
  fail "release refuses a claim comment that belongs to another item"
else
  pass "release refuses a claim comment that belongs to another item"
fi
check_not_called "-X DELETE repos/acme/widgets/issues/comments/300" "a claim on another item is never deleted"
use claims
out="$(run release 10 400 --reason 'lapsed' || true)"
check "releasing a lapsed claim reports released" "$out" '.result == "released"'
check_not_called "-X DELETE repos/acme/widgets/issues/10/labels" "releasing a lapsed claim leaves the new holder's label"

# ---------------------------------------------------------------- clear-label

use claims
if run clear-label 7 > /dev/null 2>&1; then
  fail "clear-label refuses an item with a live claim"
else
  pass "clear-label refuses an item with a live claim"
fi
check "clear-label removes a label left by a lapsed claim" "$(run clear-label 8)" '.result == "cleared"'
check_called "-X DELETE repos/acme/widgets/issues/8/labels/in-progress" "clear-label deletes the label"

# ---------------------------------------------------------------- status

use status
out="$(run status --max-worktrees 5 --max-open-prs 6 --land on)"

check "status prints one JSON object" "$out" 'type == "object"'

# Worktrees and budget
check "a squash-merged, clean worktree at the PR's head is reclaimable" "$out" \
  '.worktrees.reclaim == [{"path": "/wt/2-merged", "branch": "delegated/2-merged", "pr": 30}]'
check "worktrees that must stay are reported with a reason" "$out" \
  '[.worktrees.keep[] | [.branch, .reason]] == [["delegated/3-dirty", "uncommitted"], ["delegated/4-open", "pr-open"], ["delegated/5-nopr", "no-pr"], ["delegated/6-unpushed", "unpushed"]]'
check "the main worktree is ignored" "$out" 'all(.worktrees.keep[]; .branch != "main")'
check "budget counts worktrees after reclaim and all open PRs" "$out" \
  '.budget == {"worktrees": 4, "max_worktrees": 5, "open_prs": 6, "max_open_prs": 6, "at_limit": true}'

# Issues, in the skill's sort order
check "issues come in rank order, oldest first within a rank" "$out" \
  '[.issues[].number] == [14, 32, 31, 38, 33, 36, 37, 34, 35]'
issue() { printf '.issues[] | select(.number == %s)' "$1"; }
check "an issue with an open delegated PR is delegated" "$out" "$(issue 14) | .state == \"delegated\" and .pr == 20"
check "criteria in the body make an issue free" "$out" "$(issue 31) | .state == \"free\" and .criteria == \"body\""
check "a criteria heading with no list is not criteria" "$out" "$(issue 32) | .criteria != \"body\""
check "derived criteria without the human's thumbs-up wait on the human" "$out" \
  "$(issue 32) | .state == \"waiting-on-human\" and .reason == \"criteria-unconfirmed\""
check "derived criteria with the human's thumbs-up are confirmed" "$out" "$(issue 33) | .state == \"free\" and .criteria == \"confirmed\""
check "an answered question leaves criteria to derive" "$out" "$(issue 34) | .state == \"free\" and .criteria == \"none\""
check "an agent's reply does not answer a delegator question" "$out" \
  "$(issue 35) | .state == \"waiting-on-human\" and .reason == \"question-unanswered\""
check "an issue another session holds is claimed, with the holder" "$out" "$(issue 36) | .state == \"claimed\" and .holder == \"$OTHER\""
check "a progress label with no live claim is stale and the issue is free" "$out" \
  "$(issue 37) | .state == \"free\" and .stale_label == true"
check "an issue this session holds is held" "$out" "$(issue 38) | .state == \"held\""
check "a claimed issue's label is not stale" "$out" "$(issue 36) | .stale_label == false"

# Pick reads .pick instead of filtering .issues itself: a filter on a key that
# does not exist yields nothing, and reads as "no issue to pick".
check "pick is the first free issue in rank order" "$out" '.pick.number == 31 and (.pick | keys) == ["number", "title"]'
check "counts tallies the issues by state" "$out" \
  '.counts == {"claimed": 1, "delegated": 1, "free": 4, "held": 1, "waiting-on-human": 2}'

# PRs
pr() { printf '.prs[] | select(.number == %s)' "$1"; }
check "only delegated PRs are classified" "$out" '[.prs[].number] == [20, 21, 22, 23, 24]'
check "an unresolved thread whose last comment is the human's needs an answer" "$out" \
  "$(pr 20) | .needs_answer.threads == [{\"id\": 600, \"comment\": 601}]"
check "marker, footer, bot, preview and reply-to comments need no answer" "$out" \
  "$(pr 20) | .needs_answer.comments == [505]"
check "an unanswered review body needs an answer; an answered or bot one does not" "$out" \
  "$(pr 20) | .needs_answer.reviews == [701]"
check "a draft with comments to answer needs review" "$out" "$(pr 20) | .class == \"needs-review\""
check "a non-draft PR marked ready is Ready" "$out" "$(pr 21) | .class == \"ready\" and .latest == \"ReadyForReviewEvent\""
check "the latest land marker is reported and matched to the head" "$out" \
  "$(pr 21) | .land_marker == {\"sha\": \"h21\", \"verified\": true}"
check "a non-draft PR never marked ready is idle with land on" "$out" "$(pr 22) | .class == \"idle\""
check "a PR another session holds is claimed" "$out" "$(pr 23) | .class == \"claimed\" and .holder == \"$OTHER\""
check "a PR with a stale label is flagged and classified" "$out" "$(pr 24) | .stale_label == true and .class == \"idle\""

out="$(run status --land off)"
check "with land off, a non-draft PR with a comment to answer needs review" "$out" "$(pr 22) | .class == \"needs-review\""
check "with land off, nothing is Ready" "$out" 'all(.prs[]; .class != "ready")'
check "the default budget limits are the skill's" "$out" '.budget.max_worktrees == 1 and .budget.max_open_prs == 6'

if grep -E -- '-X (POST|PATCH|DELETE)' "$FAKE_STATE/calls.log" > /dev/null; then
  fail "status writes nothing"
else
  pass "status writes nothing"
fi

# ---------------------------------------------------------------- budget and one issue

# A hand-started Work needs the budget and its own issue, not a full pass.
use status
out="$(run budget --max-worktrees 5 || true)"
check "budget prints the worktrees and the counts status prints" "$out" \
  '.worktrees.reclaim[0].branch == "delegated/2-merged" and .budget.worktrees == 4 and .budget.open_prs == 6 and .budget.at_limit'
if grep -Fq "issue list" "$FAKE_STATE/calls.log"; then
  fail "budget reads no issues"
else
  pass "budget reads no issues"
fi

out="$(run issue 31 || true)"
check "issue classifies one eligible issue as status does" "$out" '.number == 31 and .eligible and .state == "free" and .criteria == "body"'
out="$(run issue 32 || true)"
check "issue reports why an issue waits on the human" "$out" '.state == "waiting-on-human" and .reason == "criteria-unconfirmed"'
out="$(run issue 14 || true)"
check "issue reports an issue that already has a delegated PR" "$out" '.state == "delegated" and .pr == 20'
out="$(run issue 50 || true)"
check "a closed issue is not eligible" "$out" '.eligible == false and .state == "not-eligible"'
out="$(run issue 51 || true)"
check "an issue without the label is not eligible" "$out" '.eligible == false and .state == "not-eligible"'

# Claude Code on the web answers every GraphQL request with 403, and `gh pr`,
# `gh issue` and `gh label` are GraphQL underneath, so the first status call
# of 4.26.0 failed there and nothing was ever delegated. Every call is `gh
# api` against this repository's REST endpoints.
use status
run status --land on > /dev/null
run pr 20 --land on > /dev/null
run issue 31 > /dev/null
run budget > /dev/null
if grep -v '^git ' "$FAKE_STATE/calls.log" | grep -Ev '^api (--paginate |-X [A-Z]+ )?(repos/acme/widgets/|user$)'; then
  fail "status, pr, issue and budget call only gh api REST endpoints of the repository"
else
  pass "status, pr, issue and budget call only gh api REST endpoints of the repository"
fi
check_not_called "graphql" "no GraphQL request is made while the /ccr/ routes answer"
check_called "api --paginate repos/acme/widgets/pulls/20/ccr/review_threads" "review threads come from the /ccr/ route"
check_called "api --paginate repos/acme/widgets/issues/20/timeline?per_page=100" "Ready comes from the issue timeline"
check_called "repos/acme/widgets/pulls?state=all&per_page=1&head=acme%3Adelegated%2F2-merged" "a worktree's PR is found by owner:branch"
check_called "repos/acme/widgets/issues?state=open&per_page=100&labels=agent-ready" "eligible issues are listed by label"

# A pull request is an issue to the REST API; it is never an eligible issue.
use status
jq '. + {pull_request: {}}' "$FAKE_STATE/issue-31.json" > "$FAKE_STATE/issue-31.tmp" && mv "$FAKE_STATE/issue-31.tmp" "$FAKE_STATE/issue-31.json"
check "issue refuses a pull request" "$(run issue 31 || true)" '.eligible == false'
jq '. + [{number: 60, title: "A PR", state: "open", labels: [{name: "agent-ready"}], created_at: "2026-09-01T09:00:00Z", updated_at: "2026-09-01T09:00:00Z", body: "", pull_request: {}}]' \
  "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.tmp" && mv "$FAKE_STATE/issues.tmp" "$FAKE_STATE/issues.json"
check "status lists no pull request as an issue" "$(run status || true)" 'all(.issues[]; .number != 60)'

# On the CLI, github.com has no /ccr/ routes: threads fall back to GraphQL and
# classify exactly as they do through the proxy.
use status
ccr_out="$(run pr 20 --land on || true)"
touch "$FAKE_STATE/ccr-404"
gql_out="$(run pr 20 --land on || true)"
check "a 404 from /ccr/review_threads falls back to GraphQL with the same result" "$(jq -n --argjson a "$ccr_out" --argjson b "$gql_out" '[$a, $b]')" \
  '.[0] == .[1] and .[0].needs_answer.threads == [{"id": 600, "comment": 601}]'
check_called "-f owner=acme -f repo=widgets" "the GraphQL fallback sends owner and repo as strings"

# A commit after the human's Ready leaves the PR Ready but tells Land so.
use status
printf '%s' '[{"event":"committed"},{"event":"ready_for_review"},{"event":"committed"}]' > "$FAKE_STATE/timeline-21.json"
out="$(run pr 21 --land on || true)"
check "a commit after the last ready event is reported as latest" "$out" '.class == "ready" and .ready == 1 and .latest == "PullRequestCommit"'

# A held issue still says how its criteria stand.
use status
out="$(run status --land on || true)"
check "a held issue reports its criteria" "$out" "$(issue 38) | .state == \"held\" and .criteria == \"none\""

# With nothing free, a held issue with criteria is the pick.
use status
jq '[.[] | select(.number == 14 or .number == 36 or .number == 38)]' "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.next"
mv "$FAKE_STATE/issues.next" "$FAKE_STATE/issues.json"
out="$(run status --land on || true)"
check "with nothing free, pick is a held issue with criteria" "$out" '.pick.number == 38'

# Nothing to pick is null, and counts still says why.
use status
jq '[.[] | select(.number == 14 or .number == 32 or .number == 36)]' "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.next"
mv "$FAKE_STATE/issues.next" "$FAKE_STATE/issues.json"
out="$(run status --land on || true)"
check "with nothing free or held, pick is null" "$out" '.pick == null'
check "counts names what every skipped issue is waiting on" "$out" \
  '.counts == {"claimed": 1, "delegated": 1, "waiting-on-human": 1}'

# No eligible issues at all: pick is null and counts is empty, not null.
use status
echo '[]' > "$FAKE_STATE/issues.json"
out="$(run status --land on || true)"
check "with no issues, pick is null and counts is empty" "$out" '.pick == null and .counts == {}'

# ---------------------------------------------------------------- merge conflicts

# The list endpoint carries no mergeability, so status reads each delegated PR
# on its own. A conflicted PR that nothing else claims is Conflicted, so Watch
# syncs it; one whose conflict Sync already reported for this head is idle
# until the head moves.
use status
jq '. + {mergeable: false, mergeable_state: "dirty"}' "$FAKE_STATE/pull-22.json" > "$FAKE_STATE/pull-22.tmp" && mv "$FAKE_STATE/pull-22.tmp" "$FAKE_STATE/pull-22.json"
jq '. + {mergeable: false, mergeable_state: "dirty"}' "$FAKE_STATE/pull-20.json" > "$FAKE_STATE/pull-20.tmp" && mv "$FAKE_STATE/pull-20.tmp" "$FAKE_STATE/pull-20.json"
jq '. + {mergeable: true, mergeable_state: "clean"}' "$FAKE_STATE/pull-21.json" > "$FAKE_STATE/pull-21.tmp" && mv "$FAKE_STATE/pull-21.tmp" "$FAKE_STATE/pull-21.json"
out="$(run status --land on || true)"
check_called "api repos/acme/widgets/pulls/22" "status reads each delegated PR for its mergeability"
check "a conflicted PR nothing else claims is Conflicted" "$out" "$(pr 22) | .class == \"conflicted\" and .mergeable == false and .conflicted"
check "a conflicted PR with comments to answer still needs review first" "$out" "$(pr 20) | .class == \"needs-review\" and .conflicted"
check "a mergeable PR is not conflicted" "$out" "$(pr 21) | .mergeable == true and (.conflicted | not)"
check "unknown mergeability is not a conflict" "$out" "$(pr 24) | .mergeable == null and (.conflicted | not) and .class == \"idle\""
out="$(run pr 22 --land on || true)"
check "pr reports Conflicted as status does" "$out" '.class == "conflicted" and .sync_marker == null'

printf '%s' '[{"id": 530, "body": "Sync stopped: conflict in src/a.ts.\n<!-- delegator sync: conflict h22 -->\n<!-- delegator -->", "created_at": "2026-10-01T10:00:00Z", "updated_at": "2026-10-01T10:00:00Z", "user": {"login": "rich"}}]' > "$FAKE_STATE/comments-22.json"
out="$(run pr 22 --land on || true)"
check "a conflict Sync reported for this head leaves the PR idle" "$out" \
  '.class == "idle" and .conflicted and .sync_marker == {"sha": "h22", "current": true}'
jq '.head.sha = "h22b"' "$FAKE_STATE/pull-22.json" > "$FAKE_STATE/pull-22.tmp" && mv "$FAKE_STATE/pull-22.tmp" "$FAKE_STATE/pull-22.json"
out="$(run pr 22 --land on || true)"
check "a new head after a reported conflict is Conflicted again" "$out" \
  '.class == "conflicted" and .sync_marker == {"sha": "h22", "current": false}'

# ---------------------------------------------------------------- one PR

# Review and Land read one PR: its class, and the bodies of what needs an
# answer, so the delegator can classify each request.
use status
out="$(run pr 20 --land on || true)"
check "pr reports the same class as status" "$out" '.number == 20 and .class == "needs-review"'
check "pr lists each comment needing an answer with its body" "$out" \
  '[.items[] | [.kind, .id]] == [["thread", 601], ["comment", 505], ["review", 701]]'
check "a thread item carries its thread id, path and line" "$out" \
  '.items[0] == {"kind": "thread", "id": 601, "thread": 600, "path": "src/import.ts", "line": 42, "login": "rich", "body": "Rename this please"}'
out="$(run pr 21 --land on || true)"
check "pr reports Ready, the head and the verified land marker" "$out" \
  '.class == "ready" and .head == "h21" and .isDraft == false and .land_marker.verified and .items == []'

# ---------------------------------------------------------------- writes

# The references' writes go through the script, never through GraphQL-backed
# gh commands. Each takes its text from a file, verbatim.
use claims
BODY="$FAKE_STATE/body.md"
printf '%s\n' 'Opened `#40` for this issue.' '@not-a-file' '<!-- delegator -->' > "$BODY"
out="$(run comment 12 --body-file "$BODY" || true)"
check "comment posts the file and reports the new comment" "$out" '.item == 12 and .result == "commented" and .id == 900 and (.url | endswith("#issuecomment-900"))'
check "the comment body is the file's text, a leading @ included" "$(jq '.[] | select(.id == 900)' "$FAKE_STATE/comments-12.json")" \
  '.body == "Opened `#40` for this issue.\n@not-a-file\n<!-- delegator -->"'
if run comment 12 > /dev/null 2>&1; then fail "comment without --body-file is a usage error"; else pass "comment without --body-file is a usage error"; fi

use status
BODY="$FAKE_STATE/body.md"
echo 'Renamed in abc123. <!-- delegator -->' > "$BODY"
out="$(run reply 20 600 --body-file "$BODY" || true)"
check "reply answers a thread by its first comment" "$out" '.result == "replied" and .id == 950'
check_called "-X POST repos/acme/widgets/pulls/20/comments/600/replies -F body=@$BODY" "reply posts to the thread's replies endpoint"

out="$(run pr-create --head delegated/12-fix-thing --title 'fix(web): thing (#12)' --body-file "$BODY" --draft || true)"
check "pr-create opens the PR and reports its number, URL and head" "$out" '.item == 99 and .result == "created" and .isDraft and .head == "h99"'
check_called "-f head=delegated/12-fix-thing -f base=main -f title=fix(web): thing (#12) -F body=@$BODY -F draft=true" "pr-create targets the default branch as a draft"
out="$(run pr-create --head delegated/12-fix-thing --title t --body-file "$BODY" --base release || true)"
check "pr-create opens a ready PR without --draft" "$out" '.isDraft == false'
check_called "-f base=release" "pr-create honours --base"
if run pr-create --title t --body-file "$BODY" > /dev/null 2>&1; then fail "pr-create without --head is a usage error"; else pass "pr-create without --head is a usage error"; fi

check "pr-edit rewrites the body" "$(run pr-edit 20 --body-file "$BODY" || true)" '.item == 20 and .result == "edited"'
check_called "-X PATCH repos/acme/widgets/pulls/20 -F body=@$BODY" "pr-edit patches the PR"

check "to-draft on a PR already a draft reports draft" "$(run to-draft 20 || true)" '.item == 20 and .result == "draft"'
check_not_called "pulls/20/ccr/convert_to_draft" "to-draft writes nothing to a PR already a draft: the proxy refuses that"
check "to-draft returns a PR to draft" "$(run to-draft 21 || true)" '.item == 21 and .result == "draft"'
check_called "-X POST repos/acme/widgets/pulls/21/ccr/convert_to_draft" "to-draft uses the /ccr/ route"
check_not_called "ready_for_review" "the script never marks a PR ready"
touch "$FAKE_STATE/ccr-404"
check "to-draft falls back to gh pr ready --undo where /ccr/ is absent" "$(run to-draft 21 || true)" '.result == "draft"'
check_called "pr ready --undo 21 -R acme/widgets" "the CLI fallback names the repository"

out="$(run merge 21 --sha h21 || true)"
check "merge squashes the verified head" "$out" '.item == 21 and .result == "merged" and .sha == "m1"'
check_called "-X PUT repos/acme/widgets/pulls/21/merge -f merge_method=squash -f sha=h21" "merge pins the head SHA, as --match-head-commit did"
if run merge 21 --sha h21old > /dev/null 2>&1; then
  fail "merge refuses a head that moved since it was verified"
else
  pass "merge refuses a head that moved since it was verified"
fi
if run merge 21 > /dev/null 2>&1; then fail "merge without --sha is a usage error"; else pass "merge without --sha is a usage error"; fi

# ---------------------------------------------------------------- checks

use status
out="$(run checks 20 || true)"
check "checks reports pending runs and statuses on the PR head" "$out" \
  '.item == 20 and .head == "h20" and .state == "pending" and .pending == ["test"] and .failing == [] and .total == 3'
out="$(DELEGATE_STATUS_POLL=0 run checks 20 --wait 60 || true)"
check "checks --wait polls until nothing is pending" "$out" '.state == "pass"'
check "a re-run check counts by its latest run" "$out" '.failing == [] and .total == 3'
out="$(run checks 21 || true)"
check "a failing run or status fails the checks" "$out" '.state == "fail" and ([.failing[].name] | sort) == ["deploy", "test"]'
check "a failing run names its Actions run and its failure annotations" "$out" \
  '.failing[] | select(.name == "test") | .run == 9100 and .summary == "2 tests failed" and .annotations == [{"path": "src/import.test.ts", "line": 12, "message": "expected [] to equal [1]"}]'
check "a skipped run does not fail the checks" "$out" 'all(.failing[]; .name != "lint")'
check "a status counts by its latest report" "$out" '.failing[] | select(.name == "deploy") | .summary == "Deploy failed"'
check "no checks reported is none, not pass" "$(run checks 22 || true)" '.state == "none" and .total == 0'
: > "$FAKE_STATE/calls.log"
start=$(date +%s)
out="$(DELEGATE_STATUS_POLL=0 run checks 21 --wait 60 || true)"
if [ $(($(date +%s) - start)) -lt 5 ] && [ "$(printf '%s' "$out" | jq -r .state)" = fail ]; then
  pass "checks --wait stops at the first failure"
else
  fail "checks --wait stops at the first failure"
fi

check "merged-sizes reads the newest merged PRs' sizes" "$(run merged-sizes || true)" \
  '.prs == [{"number": 19, "additions": 190, "deletions": 19, "changedFiles": 3}, {"number": 17, "additions": 170, "deletions": 17, "changedFiles": 3}]'

# ---------------------------------------------------------------- Pick skip cache

use status
CACHE="$FAKE_STATE/pick-cache.json"
run status --cache "$CACHE" > /dev/null
check "the cache records each skipped issue with its reason, but not unconfirmed criteria" "$(cat "$CACHE")" \
  '[.[] | [.number, .reason]] | sort == [[35, "waiting-on-human"], [36, "claimed"]]'

: > "$FAKE_STATE/calls.log"
out="$(run status --cache "$CACHE")"
check_called "issues/32/comments" "unconfirmed criteria are re-read every pass: a thumbs-up does not bump updatedAt"
check_not_called "issues/35/comments" "an unchanged unanswered question is not re-read"
check_not_called "issues/36/comments" "a recently claimed issue is not re-read"
check "a cached skip keeps its state" "$out" "$(issue 35) | .state == \"waiting-on-human\" and .cached == true"

jq 'map(if .number == 32 then .updated_at = "2026-10-02T11:59:00Z" else . end)' \
  "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.tmp" && mv "$FAKE_STATE/issues.tmp" "$FAKE_STATE/issues.json"
jq 'map(if .number == 35 then .updated_at = "2026-10-02T11:59:00Z" else . end)' \
  "$FAKE_STATE/issues.json" > "$FAKE_STATE/issues.tmp" && mv "$FAKE_STATE/issues.tmp" "$FAKE_STATE/issues.json"
: > "$FAKE_STATE/calls.log"
run status --cache "$CACHE" > /dev/null
check_called "issues/35/comments" "an issue updated since it was cached is re-read"

: > "$FAKE_STATE/calls.log"
RUN_NOW=$((NOW + 14401)) run status --cache "$CACHE" > /dev/null
check_called "issues/36/comments" "a claimed issue is re-read once claim_ttl has passed"

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
