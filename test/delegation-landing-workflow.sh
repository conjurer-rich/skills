#!/usr/bin/env bash
#
# Guard the delegation landing policy: who may mark a PR ready, how the
# delegator tells its own comments from the human's, and what Land may and may
# not do before it merges.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills/delivery/delegating-github-issues"
CORE="$SKILL_DIR/SKILL.md"
FAILURES=0

# The skill is a short core plus one reference file per entry point. The
# text guards below read them as one document; the structure guards after
# them check what lives where.
SKILL="$(mktemp)"
trap 'rm -f "$SKILL"' EXIT
cat "$CORE" "$SKILL_DIR"/references/*.md > "$SKILL"

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

require_text() {
  local pattern="$1" label="$2"

  if grep -Fq -- "$pattern" "$SKILL"; then
    pass "$label"
  else
    fail "$label"
  fi
}

# Computation moved out of the prose into scripts/delegate-status; its
# behaviour is tested in test/delegate-status.sh, and these pins check the
# script still carries the protocol's fixed strings.
DELEGATE_STATUS="$SKILL_DIR/scripts/delegate-status"
require_script() {
  local pattern="$1" label="$2"

  if grep -Fq -- "$pattern" "$DELEGATE_STATUS"; then
    pass "$label"
  else
    fail "$label"
  fi
}

reject_regex() {
  local pattern="$1" label="$2"

  if grep -Eiq -- "$pattern" "$SKILL"; then
    fail "$label"
  else
    pass "$label"
  fi
}

# Task 1: parameter, drafts, marker, Never list
require_text '| `land` | off |' "land parameter defaults to off"
require_text 'add `--draft` when `land` is on' "Work opens a draft when land is on"
require_text '<!-- delegator -->' "delegator comments carry the marker"
require_text 'Every comment and thread reply the delegator posts therefore ends with' "every delegator post is marked"
require_text 'does not end in `[bot]`' "bot comments never need an answer"
require_text 'does not contain `<!-- preview-`' "preview stickies never need an answer"
require_script 'list_of "repos/$REPO/issues/$1/comments"' "Review reads top-level PR comments"
require_text 'Merge a PR, except through **Land** with `land` on.' "merging is confined to Land"
require_text 'Mark a PR ready for review; only the human does. `delegate-status to-draft` is the delegator'"'"'s one draft-state change.' "only the human marks a PR ready"
reject_regex 'ready_for_review`? *(route|endpoint)|ccr/ready_for_review' "the skill never names the route that marks a PR ready"
reject_regex 'merge a PR, resolve a review thread' "the unconditional never-merge line is gone"

# Task 2: Watch
require_text '# Watch' "Watch entry point exists"
require_text 'counted over the PR timeline'"'"'s `ready_for_review` events only' "Ready is read from the PR timeline"
# timelineItems' totalCount ignores itemTypes and counts every timeline item,
# so a gate on it calls every PR ready. filteredCount is the filtered count.
require_script '([$tl[] | select(. == "ready_for_review")] | length) as $ready' "Ready counts only ready events"
require_text '`isDraft` is false and `ready` is above 0' "Ready gates on the ready-event count"
reject_regex 'totalCount' "no gate reads the unfiltered timeline count"
if grep -q totalCount "$DELEGATE_STATUS"; then fail "the script never reads the unfiltered timeline count"; else pass "the script never reads the unfiltered timeline count"; fi
require_text 'never Ready' "a PR opened as non-draft is never landed"
# The watcher may run on a machine that did not open the PR, so Review, not
# just Land, must be able to create the worktree it needs.
require_text 'If none exists (another machine or session opened the PR), `git fetch origin <head branch>`, then `git worktree add <path> <head branch>`' "Review creates a missing worktree"
require_text 'Find or create the branch'"'"'s worktree as in **Review** step 2.' "Land reuses Review's worktree step"
require_text 'holds no state between passes' "Watch keeps no local state"
# A foreground CI wait held the whole watcher for up to 27 minutes in dry run 2.
# Land's long waits run in the background and wake the loop when they finish.
require_text 'the background task that finishes wakes the loop' "a Land waiting in the background wakes the loop itself"
reject_regex '270 seconds' "Watch no longer polls fast to babysit CI"

# Task 3: Land
require_text '# Land `#PR`' "Land entry point exists"
require_text 'If `land` is off, say so and stop.' "Land refuses when land is off"
require_text 'git merge --no-edit origin/<default branch>' "conflicts are resolved by merging main in"
require_text '<!-- delegator land: reviewed <sha> -->' "Land records the SHA it verified"
require_text 'no checks reported' "a docs-only PR with no CI checks can land"
require_text 'Check `isDraft` again' "a PR returned to draft mid-land is not merged"
require_text '`delegate-status merge <PR> --sha <verified SHA>`' "only the verified head is merged"
require_script '-f merge_method=squash -f sha="$SHA"' "the merge is a squash pinned to the verified SHA"
require_text 'Fix or answer, then mark the PR ready again.' "bail-out hands the PR back to the human"
reject_regex 'git rebase|git push (--force|-f)' "Land never rebases or force-pushes"
require_text 'force-push, or rebase a pushed branch' "the Never list forbids force-push and rebase"
require_text 'If the PR is now a draft, its head is no longer the verified SHA, or a comment needs an answer, stop without merging.' "a PR changed mid-land is not merged"
require_text 'continue only when every changed path is one the project'"'"'s CI ignores' "no checks passes only for CI-ignored paths"

# Review findings: resume, late commits, answers, unattended failures
require_text 'Steps 1–3 always run, including on resume.' "resuming Land still checks eligibility"
require_text 'Bail-out** with the reason `commits after Ready`' "a commit pushed after Ready is not landed"
require_text '<!-- delegator reply-to: <comment id> -->' "a top-level answer names the comment it answers"
require_script 'list_of "repos/$REPO/pulls/$number/reviews?per_page=100"' "a review summary body is read as a comment"
require_text 'review body (`review`)' "Review answers review bodies too"
require_text 'Never go to **Blocked** from **Watch** or **Land**.' "an unattended run never waits on approval"
require_text 'delegate-status checks <PR> --head <verified SHA> --wait 2400 --table` as a background task' "the CI wait runs in the background, pinned to the verified head"
# A bare checks wait returned before any check had started and read as green.
require_text 'never a CI wait that is not pinned to the head SHA' "Land never waits on an unpinned checks call"
require_text '`none`, no checks reported: never green' "no checks yet is never green"
reject_regex 'timeout 540' "no foreground CI wait sized to one tool call"
require_text 'If `merge` exits non-zero or prints `refused`, go to **Bail-out**' "a refused merge hands the PR back"
require_text 'which squash-merges only while the head is still that SHA' "Land merges only the head it verified"
reject_regex 'search "head:' "Watch filters branches locally, not by fuzzy search"

# Dry run 2 findings (#1708, #1710)
# Land's review took 24 minutes; a foreground subagent froze the watcher.
require_text 'with `subagent_type: general-purpose`, `model: <review_model>`, `run_in_background: true`' "Land's review runs in the background"
require_text 'A review interrupted by a restart leaves staged changes' "a restarted Land discards a dead review's changes"
# Another agent session answered a thread without the marker, and the watcher
# treated its reply as the human's.
require_text 'it does not contain the Claude Code footer' "an unmarked agent reply is not the human's"
# Rich accepted three bail-out findings as follow-ups; the next Land must not
# bail on them again, and must learn that from GitHub, not local state.
require_text 'Findings listed under the PR body'"'"'s `## Found on the way, not fixed here` are accepted' "Land's review skips accepted findings"
require_text 'asks for findings as follow-ups' "Review files follow-ups when the human asks"
require_text 'To accept a finding instead, ask for it as a follow-up.' "bail-out says how to accept a finding"
# A bail-out on findings threw away a verified simplification that the next
# Land then had to redo.
require_text 'keep verified simplifications' "a bail-out on findings keeps verified simplifications"
# A squash merge leaves no ancestry, so reclaim compares head SHAs.
require_text 'equals the PR'"'"'s `headRefOid`' "reclaim matches a squash-merged branch by head SHA"
reject_regex 'and `git log origin/[^`]*` prints nothing' "reclaim never gates on ancestry"

# Skill-graph review: nothing independent checked the acceptance criteria or
# the whole diff before the human saw the PR, and the walkthrough's Fix step
# had the delegator writing production code after tdd-guardian had run.
require_text 'The implementer'"'"'s returns are claims, not evidence.' "the implementer's own report is not the evidence"
require_text 'loads `acceptance-review`' "acceptance criteria are checked independently"
require_text 'The project'"'"'s whole-PR review agent' "the whole diff is reviewed before the PR opens"
require_text 'do **not** run its Fix step' "the delegator never applies walkthrough fixes itself"
require_text 'Then re-run the checks for the tier, measured again from the fresh (g): at tier M or L, `tdd-guardian` and every check that reported a blocking finding, as step 7 dispatches them; at tier S, the one reviewer.' "the repair round is re-checked"
require_text 'edit this comment to change them, then react' "derived acceptance criteria wait for the human"
require_text 'including any glossary or vocabulary check' "the gate's glossary step is not dropped"
reject_regex 'gate'"'"'s steps 1–5' "the pre-PR gate is not truncated"

# Second pass on the skill-graph changes: a waiting issue must not be
# re-posted or jam Pick, only the human's own reaction confirms, the repair
# round refreshes the gate evidence, and the verdict words match the checkers.
require_text 'post nothing, and stop' "a waiting issue is never re-posted"
require_text 'Take the first issue that is not waiting on the human' "Pick skips issues waiting on the human"
require_script 'gh_json api user' "only the authenticated login's reaction confirms"
require_script '.content == "+1" and .user.login == $l' "only a thumbs-up from that login confirms"
require_text 'Only that login'"'"'s reaction counts' "the skill says why only that login counts"
require_text 'does not rate `Covered`' "acceptance verdicts use acceptance-review's statuses"
require_text 'rated Critical or High Priority' "whole-diff severity uses pr-reviewer's scale"
require_text 'returns (a)–(g) afresh' "the repair round refreshes the gate evidence and the tier measurement"
require_text 'wait for it to exit' "the implementer waits for the background suite"
require_text 'On every path out of this step except **Blocked**' "the UX walkthrough section is written with or without a repair"
require_text 'the PR already exists, so **Blocked** does not apply' "a human-started Review never opens a second PR"

# Run: one unattended pass of Watch then Pick and Work, built for /loop.
require_text '# Run' "the skill has a Run entry point"
require_text 'When **Run** started this Work, commit without asking' "Work under Run commits without asking"
require_text 'skip Pick without commenting' "an over-budget Run pass never posts a paused comment"
require_text 'a Run pass never waits on the human' "Run never blocks on a human answer"

# Several sessions run /loop /delegate at once through one gh login, so
# assignees and labels cannot tell them apart. A claim comment names the
# session; the lowest live comment id settles a race; a lease lets a crashed
# session's claim lapse instead of locking the issue for good.
require_text '| `claim_ttl` | 45 minutes |' "claims lapse 45 minutes after their last heartbeat"
# Duplicate sessions claimed the same issue or PR and fought over it.
require_text 'When another session holds a live claim, it posts nothing, prints `lost` with the `holder` and exits 4' "a claim held by another session is refused with exit 4"
require_text 'On exit 4, stop work on the item, never retry or take over' "a refused claim stops the run"
require_text '- **Heartbeat.** After a won claim, run `heartbeat <n> <id>` as a background task until you release.' "a won claim keeps a heartbeat"
require_text '<!-- delegator claim: <session> -->' "a claim names the session holding it"
require_text 'live claim with the lowest comment id wins' "a race between two sessions has one winner"
require_text 'the loser deletes its own claim comment and exits 4' "the losing session withdraws its claim"
require_text 'Every stop releases the claim' "a session releases its claim on every exit"
require_text '<!-- delegator claim-released: <session> -->' "a released claim stays readable on the issue"
require_text 'Skip an issue that has an open PR from a `<branch_prefix><n>-` branch' "Pick never re-picks an issue that already has a PR"
require_text 'skip an issue another session holds a live claim on' "Pick skips issues another session claimed"
require_text 'otherwise say this PR was not opened by a delegated run and stop. Then claim the PR (**Claims**)' "Review claims the PR before touching it"
require_text 'say so and stop. Then claim the PR (**Claims**); if another session holds it, stop. The PR must be **Ready**' "Land claims the PR before it can bail out"
require_text 'Confirm before any push, PR creation or merge.' "a session that lost its claim writes nothing more"
require_text '12. **PR.** Renew the claim (**Claims**) before pushing, then `git -C <worktree> push -q -u origin <branch>` (never with a force flag)' "Work renews its claim before it pushes"
require_text 'Renew the claim, then ship inline as **Work** steps 10 and 12 do, without PR creation: it commits from the message file and pushes with no force flag' "Review renews its claim before it pushes"
require_text 'then `git -C <worktree> push -q`, with no force flag' "Land pushes inline with no force flag"
require_text 'then `git push`, with no force flag; it returns the new head SHA' "Land's merge-commit ship subagent pushes with no force flag"
require_text '6. **Commit and push.** Commit without asking. Renew the claim. Step 4'"'"'s merge' "Land renews its claim before it pushes"
require_text 'Otherwise confirm the claim is still yours and run `delegate-status merge <PR>' "Land confirms its claim before merging"
# Review of the first draft: a lapsed claim keeps its low id, so renewing it
# blindly steals the item back; and a session that released on opening its PR
# left a window for another session to claim the issue again.
require_text '`renew <n> <id>` confirms, then rewrites the claim'"'"'s first line' "renewal never revives a lapsed claim"
require_text 'a lapsed claim prints `lost` and nothing is written' "a lapsed claim is not renewed"
require_text 'It reuses this session'"'"'s live claim, so a session never claims an item twice.' "a session never claims the same item twice"
require_text 'once claimed an open PR from a `<branch_prefix>N-` branch now exists' "a claim won just after another session opened its PR stops"
require_text 'A stop that posted nothing else on the item deletes the claim comment' "a waiting issue is still left without new comments"
require_text 'Comments that carry the delegator marker do not count as a change' "one session's claims do not wake every other session's poll"
require_text 'Edit or delete another session'"'"'s claim' "the Never list protects other sessions' claims"
# A claim comment is only visible once the issue is opened, so the issue list
# could not show what an agent was working on. A label shows it at a glance,
# but a label cannot carry a session name or lapse, so it stays a signal and
# the comment stays the lock.
require_text '| `progress_label` | `in-progress` |' "a label marks an item an agent is working on"
require_text 'The claim comment is the lock' "the label never decides who holds an item"
require_text 'it never decides who holds an item' "the label is only a signal"
require_script '"repos/$REPO/issues/$n/labels" -f "labels[]=$PROGRESS_LABEL"' "a winning claim adds the label"
require_text 'The winner adds the label' "only the winning session adds the label"
require_text 'which removes the label first' "every release removes the label"
require_script 'gh api -X DELETE "repos/$REPO/issues/$1/labels/$(uri "$name")"' "the script removes the label through the labels endpoint"
require_script 'gh api -X POST "repos/$REPO/labels" -f name="$name"' "a missing label is created"
require_text 'Never `--force`' "an existing label keeps the human's colour and description"
require_text '**Stale label.**' "a crashed session's label is cleaned up"
require_text 'remove the label as **Stale label** in **Claims** says, and keep it as a candidate' "Pick does not skip an issue on a stale label"
require_text 'with no live claim is not Claimed' "Watch does not skip a PR on a stale label"
require_text 'Put `<progress_label>` on an item without holding a live claim on it' "the Never list forbids a label without a claim"

# A /loop /delegate run in a cloud container worked three issues at once and
# used the delegator's whole context in one pass: EnterWorktree pinned it to one
# worktree so every other git command was refused by the isolation guard, the
# browser walkthrough and the commit/push/PR steps ran inline, claims
# bookkeeping was thirty gh calls in the main context, every subagent report
# came back in full, Pick re-read every skipped issue on every pass, and nothing
# told the run to stop. Each guard below pins one of the fixes.
# A. The delegator never enters a worktree.
reject_regex 'EnterWorktree' "the skill no longer uses EnterWorktree"
require_text 'git worktree add <path> -b <branch_prefix>N-<slug> origin/<default branch>' "the worktree is created from the main checkout"
require_text 'Stay in the main checkout: the delegator never enters the worktree' "the delegator stays in the main checkout"
require_text 'It runs no `git` command inside a worktree other than `git worktree add`, `git worktree list`, `git worktree remove`, `git worktree prune`, `git -C <path> status --porcelain` for Reclaim, and the three shipping commands above (`git -C <path> commit -q -F`, `git -C <path> push -q`, `git -C <path> rev-parse HEAD`).' "the delegator's in-worktree git commands are Reclaim's and the three shipping ones"
require_text 'then dispatch the bootstrap subagent as **Work** step 5 does. Never enter it' "Review never enters the worktree either"
require_text 'work only inside `<path>`' "subagents are briefed with the worktree path"
# B. Mechanical steps run in subagents under one hand-back contract.
require_text '# Hand-back contract' "the skill has a Hand-back contract section"
require_text 'returns to the delegator **at most ten lines**' "a subagent returns at most ten lines"
require_text 'It never returns a diff, a screenshot, a browser snapshot, a test log, or a report body.' "a subagent never returns its output body"
require_text 'The delegator never runs `git diff` itself' "the delegator never reads a diff"
require_text 'Write to `<scratch>/<N>/implementer.md`: (a) the list of files changed' "the implementer report goes to a file"
require_text 'its full report goes to `<scratch>/<N>/checks/<process|acceptance|whole-diff>.md`' "the three checks report to files"
require_text '     - **Process.** The project'"'"'s `tdd-guardian` agent, or else a subagent that loads the `tdd-guardian` skill.' "the tdd-guardian check is unchanged"
require_text 'dispatch one walkthrough subagent' "the walkthrough runs in a subagent"
require_text 'The delegator never runs `agent-browser`' "the delegator never drives the browser"
require_text 'The re-walk never runs in the main session.' "the repair-round re-walk runs in a subagent"
# Every commit-and-push subagent started at about 60k tokens of inherited
# context, for three fixed commands. Commit, push, PR creation and the CI wait
# now run inline, with their output in a log file, and a subagent gets a
# self-contained brief on the cheapest model that can do its step.
require_text '**Shipping inline.** Commit, push, PR creation and the CI wait are fixed commands, so the delegator runs them itself' "commit, push, PR and CI wait run inline"
require_text 'each with its output appended to `<scratch>/<N>/ship.log`' "shipping output goes to a log, not the context"
require_text 'with no `echo`, loop or pipe' "the inline commands need no extra permission"
require_text 'If the environment refuses `git -C` (an isolation guard), do not rephrase it: dispatch one ship subagent on `model: <mechanical_model>` instead' "a refused git -C falls back to a mechanical-model ship subagent"
require_text '**Self-contained briefs.** A subagent starts from its brief alone. Never fork the conversation into it' "subagents never inherit the conversation"
require_text 'Fork the conversation into a subagent; every brief is self-contained.' "the Never list forbids forking the conversation"
require_text '**Cheapest model that can do the step.** Mechanical steps, where the brief names every command, run on `model: <mechanical_model>` (default `haiku`)' "mechanical steps run on the cheapest model"
require_text 'The delegator commits only from the message file and runs nothing else in the worktree.' "the delegator commits only from the message file"
require_text '11. **Evidence.** If there are screenshots under `<scratch>/<N>/`, dispatch one evidence subagent on `model: <mechanical_model>`' "evidence is pushed by a mechanical-model subagent"
require_text 'with the proposed message shown, **before** you ship' "a hand-started Work asks for commit approval before shipping"
require_text 'Push whatever is staged as a draft PR, inline as the **Hand-back contract** ships' "Blocked ships inline too"
# C. Claims bookkeeping goes to one subagent, renewed less often.
require_text '`scripts/delegate-status`, in this skill'"'"'s directory, runs the claims and every fixed query' "claims bookkeeping runs in the script, not the main context"
reject_regex 'Bookkeeping subagent' "the claims subagent is gone"
require_text '`claim <n>` prints `won` with the `id`' "a claim prints won or lost"
require_text 'Keep claim ids in `claims.json`' "claim ids live in claims.json"
require_text 'Renew in place of Confirm before every push and before a hand-off; without a heartbeat, also before each long step (Work steps 6–9, Review step 5, Land steps 5 and 7, Sync steps 3 and 4).' "renewal happens at every push and hand-off"
require_text 'Only when it returns `tier: not S`, dispatch **Process** and **Acceptance**' "tier S adds the other checks only when the reviewer re-tiers the diff"
require_text 'Renew the claim (**Claims**), then dispatch one subagent' "Work renews before the handoff"
require_text 'renew the claim and dispatch one walkthrough subagent' "Work renews before the walkthrough"
require_text 'Otherwise renew the claim, then send the implementer subagent' "Work renews before the repair round"
require_text 'Renew the claim, then hand the actionable threads' "Review renews before its handoff"
require_text 'Renew the claim, then dispatch one subagent with `subagent_type: general-purpose`, `model: <review_model>`, `run_in_background: true`' "Land renews before its review wait"
require_text '**Wait for CI.** Renew the claim, then run' "Land renews before its CI wait"
# D. Pick caches skips across loop passes.
require_script 'updatedAt: .updated_at' "Pick lists updatedAt"
require_text '`pick-cache.json`' "Pick keeps a skip cache"
require_text 're-reads a cached issue'"'"'s comments **only** when its `updatedAt` is later than the cached value' "a cached skip is re-read only when the issue changed"
require_text 'A cached skip is reported once per run' "a cached skip is reported once"
# E. One issue per session.
require_text '| `max_worktrees` | 1 |' "max_worktrees defaults to 1"
require_text 'Parallelism comes from running several `/loop /delegate` sessions, each claiming its own issue; it does not come from one session working several issues.' "parallelism comes from more sessions"
require_text 'One Run pass works at most one issue through to its PR before the loop reschedules' "a Run pass works one issue"
# F. A run-level stop rule.
require_text '## Stop rule' "the skill has a Stop rule section"
# About 70% of spend came from long-lived sessions re-reading 110–175k
# tokens on every turn. Sessions hand off at about half that, and work one issue.
require_text '- **Hand-off threshold**: context use above 50 %, more than 80 tool calls in the main session, or a finished Work.' "the hand-off threshold is half the old stop"
require_text '- **Hard stop**: context use above 80 %, more than 150 tool calls, or the same isolation-guard refusal three times.' "the hard stop keeps the old triggers"
require_text 'a session works **one issue**: once it has worked one, it never picks another' "a session works one issue"
require_text 'unless `worked_issue` is set in `run-state.json`' "Run never picks a second issue in a session"
require_text '<!-- delegator:handoff -->' "the hand-off is a structured PR comment"
require_text '- **Done:**' "the hand-off names what is done"
require_text '- **Next:**' "the hand-off names the next step"
require_text '- **Verified:**' "the hand-off names verified commands and results"
require_text '- **Open threads:**' "the hand-off names open review threads"
require_text '- **Traps:**' "the hand-off names traps hit"
require_text 'reads it before its first step and does not re-derive what it says' "the next session reads the hand-off instead of re-deriving"
require_text '`run-state.json`' "the stop counters live in run-state.json"
require_text 'The new session starts a fresh Run, not the stopped Work.' "a stopped run's successor starts fresh"
# A /loop wakeup is a new turn in the same session, so a run that stopped at
# the context limit tripped the rule again on every later pass and the loop died.
# A cloud session hands the loop to a new session with an empty context.
require_text '## Hand-off' "the skill has a Hand-off section"
require_text 'A skill cannot run `/clear` or `/compact`' "hand-off says why the session cannot clear itself"
require_text 'the `create_session` tool of the `claude-code-remote` MCP server' "hand-off starts the next session through create_session"
require_text 'set to the exact `/loop` command this session was started with' "the next session runs the same loop"
require_text 'and trips the context or tool-call rule before finishing one pass' "a hand-off chain cannot loop forever"
require_text 'call `ScheduleWakeup` with `stop: true`' "the stopped session ends its own loop"
require_text 'unsubscribe every PR in `subscribed.json`' "the stopped session stops taking PR events"
require_text 'Do not archive this session' "the stopped session keeps its staged worktree"
require_text 'A stop on isolation-guard refusals never hands off' "a guard-refusal stop ends the loop"
# Only a /loop run handed off, so a /delegate #<n> that hit the context or
# tool-call limit stopped and waited for the human to start a new session.
require_text 'It then follows **Hand-off**, under `/loop` or not' "every stopped run hands off, not only a loop"
require_text 'or, for a run started by hand, the exact `/delegate` command with its arguments' "a hand-started run's successor runs the same command"
# A ScheduleWakeup timer lives in the container, which is reclaimed while the
# session idles, so the loop stalled for hours until a PR event or the human
# woke it. On the web the next pass is a server-side send_later reminder.
require_text 'call it once with `delay_minutes` set to `next_interval_minutes`, `message` set to the exact `/loop` command this session was started with' "the web loop schedules its next pass with send_later"
require_text 'Do not also call `ScheduleWakeup`: two schedulers would fire two passes.' "the web loop never double-schedules"
require_text 'Otherwise (the CLI), call `ScheduleWakeup`' "the CLI loop still uses ScheduleWakeup"
require_text 'that reminder has not fired: cancel it with `delete_trigger`' "every pass cancels the pending reminder first"
require_text 'Cancel a pending `next_pass_trigger` reminder as **Watch** step 1 does' "a hand-off leaves no pending reminder"
require_text 'That is why the loop schedules its next pass with `send_later`' "the cloud advice says why the loop uses send_later"
# Hand-off sessions landed under "Other" in the sidebar: create_session with
# only source_url records no outcome repository, which the sidebar groups by.
require_text '`outcome_branch` the branch in `ccr-outcome-branch`' "the next session is grouped under its repository"
require_text 'write its first outcome branch to `ccr-outcome-branch`' "the outcome branch is kept with the session id"
# A stopped session looked like any other in the sidebar, so the human could
# not tell which sessions had handed their loop on, or to whom.
require_text '| **Hand-off** step 3, once the next session starts | `[handed off → <id>] <title>` |' "a handed-off session says so in its title"
require_text '| **Hand-off** ends the loop without a next session | `[loop ended] <title>` |' "an ended loop says so in its title"
require_text 'the last 8 characters of the new session'"'"'s id' "the title names the session it handed off to"
# The report named the new session only by id, so the human had to find it in
# the sidebar; it now links to the session.
require_text 'plus the new session as a clickable link, `[<id>](https://claude.ai/code/<session id>)`' "the hand-off report links to the new session"
# G. Cloud container guidance.
require_text '## Running in a cloud container' "the skill has cloud container guidance"
require_text 'only the GitHub connector attached' "the guidance names the connector cost"
require_text '`.delegator/` marker directory or `DELEGATOR_RUN=1`' "the stop hook exemption is named"
# H. Never-rules that the rewrite must keep.
require_text 'You do not write production code' "the delegator writes no production code"
require_text 'A session touches only its own claim comments.' "the claims never-rule survives"
require_text 'a command that a subagent'"'"'s own permission system refused' "no permission laundering"
require_text 'Put a model identifier in anything pushed' "no model identifier is pushed"
require_text '`git stash`, `git commit --amend` on a pushed branch, or `git branch -D`' "stash, amend and branch -D stay forbidden"
require_text 'One round only.' "one repair round only"

# Several /loop /delegate sessions in the sidebar or the /resume picker all
# read "/delegate", so the human could not tell which one held which issue.
# The session names its chat after the item it holds, through the one
# mechanism each host offers, and a failed rename never stops a run.
require_text '## Session title' "the skill has a Session title section"
require_text 'the two never mix' "the claims session name and the chat title are kept apart"
require_text '| **Work** step 2, once the claim on issue N wins | `#N <issue title>` |' "Work names the chat after the issue"
require_text '| **Review** step 1, once the claim on PR P wins | `Review PR #P <PR title>` |' "Review names the chat after the PR"
require_text '| **Land** step 1, once the claim on PR P wins | `Land PR #P <PR title>` |' "Land names the chat after the PR"
require_text '| A **Watch** or **Run** pass ends and the session has held no item yet (`title` in `run-state.json` is empty) | `/delegate watching <owner>/<repo>` |' "only a session that has held nothing is named watching"
# A session renamed itself to the watching form after every pass, so the
# human could not tell which session had handled which PR. The title now
# keeps the last item, and Work adds the PR number once the PR opens.
require_text 'once a session has worked an item it never goes back to the watching form' "a session keeps its last item's title"
require_text '| **Work** step 12, once the PR opens | `PR #P (#N) <issue title>` |' "Work names the chat after the PR it opened"
require_text 'and set the **Session title** to `PR #P (#N) <issue title>`.' "Work sets the PR title once the PR opens"
require_text 'Once the claim is yours, set the **Session title** to `#N <issue title>`.' "Work sets the title once its claim wins"
require_text 'Once the claim is yours, set the **Session title** to `Review PR #P <PR title>`.' "Review sets the title once its claim wins"
require_text 'Once the claim is yours, set the **Session title** to `Land PR #P <PR title>`.' "Land sets the title once its claim wins"
require_text 'Set the **Session title** to its watching form only if the session has held no item yet' "Watch and Run set the watching title only before a first item"
require_text 'and only when the new title differs from `title` in `run-state.json`' "an unchanged title costs no call"
require_text 'never stops a run: the title is a convenience' "a failed rename never stops a run"
require_text 'The `set_session_title` tool of the `claude-code-remote` MCP server' "a cloud session renames through the set_session_title tool"
require_text '`CLAUDE_CODE_SESSION_ID` is a different id and is not it' "the cloud rename does not use the CLI session id"
require_text 'customTitle:$t,sessionId:$s' "a CLI session appends the custom-title record /rename writes"
require_text '>> ~/.claude/projects/*/"$CLAUDE_CODE_SESSION_ID".jsonl' "the record goes to this session's transcript"
reject_regex 'Skill tool.*/rename|run `/rename`[^.]*\.$' "the skill never tells the model to run /rename itself"

# Size tiers. A +83-line fix and a +2.5k-line feature went through the same
# three independent checks. A small diff off the risk paths gets one
# independent reviewer that also checks the criteria; it never gets none.
require_text '| `tier_small_max_lines` | 150 |' "tier S has a line threshold"
require_text '| `tier_small_max_packages` | 1 |' "tier S has a package threshold"
require_text '| `risk_paths` | none |' "risk paths default to none"
require_text 'A diff that touches any `risk_paths` glob is never tier S.' "a risk path is never tier S"
require_text '`git diff --cached --shortstat`' "the tier is measured from the staged diff"
require_text 'Record the tier and its measurement in the PR body'"'"'s **Summary**.' "the tier is recorded in the Summary"
require_text '**Tier S.** Dispatch one independent reviewer' "tier S gets one reviewer"
require_text 'checks each acceptance criterion against the tests' "the tier S reviewer checks the criteria"
require_text 'No tier skips independent verification.' "no tier skips verification"
require_text 'The tier is a claim too' "the tier S reviewer re-measures the tier"
require_text '**Tier M or L.** Dispatch these three read-only checks in parallel' "tier M and L keep the three checks"
require_text 'The RED-before-GREEN evidence goes in the PR body at every tier.' "tier S keeps TDD evidence in the PR"

# Token-cost review of fast-flow-board delegated sessions. Each guard pins
# one fix; every new key degrades to the old behaviour when a project leaves
# it out.
# Tiers and verification scope come from the project's delegation file.
require_text '| `full_suite_paths` | none |' "full_suite_paths defaults to none"
require_text '| `preflight` | none |' "preflight defaults to none"
require_text 'defaults apply when it does not, and keep the behaviour from before a parameter existed' "unset parameters keep the old behaviour"
require_text 'it replaces the `pre_pr_gate`'"'"'s complete-suite rule' "a Verification scope section replaces the complete-suite rule"
require_text 'Copy the section verbatim into every implementer, repair-round and Land brief' "the project's scope reaches the implementer verbatim"
require_text '`Verification scope: project` or `Verification scope: default`' "the PR body records what was verified"
require_text 'An expected tier S brief tells the implementer: no separate plan document' "tier S writes no plan document"
require_text 'one self-contained reviewer that also checks the criteria' "tier S gets one self-review"
# Preflight is read from the project, never hard-coded.
require_text 'A `preflight:` line in the project'"'"'s delegation file names the project'"'"'s own drift fixers' "preflight comes from the project's file"
require_text 'The skill hard-codes no fixer.' "no fixer is hard-coded"
require_text 'Before a PR'"'"'s first push, the implementer runs each preflight command in order' "preflight runs before the first push"
reject_regex 'mutate:follow' "the skill names no project's fixer"
# Idle /loop passes cost almost as much as working passes.
require_text 'ends an unchanged pass without reading any reference file' "an unchanged pass reads no reference file"
require_text 'so they are never news' "the delegator's own writes never wake a full pass"
require_text '`next_interval_minutes` is 10 after a full pass and doubles with each idle pass in a row: 20, 40, then 60 at most.' "idle passes back off to 60 minutes"
require_text 'a full pass runs at least that often' "a full pass still runs once per claim_ttl"
require_text 'Record the digest baseline (`watch-digest --state <scratch>/delegator/watch-digest.json --record`' "a full pass records the digest baseline first"
require_script 'cmd_watch_digest()' "the script computes the Watch digest"
# One PR stayed blocked on findings it did not cause.
require_text '## Not this PR'"'"'s' "Review has a rule for findings the PR did not cause"
require_text 'when the same thing fails on the default branch' "a finding counts as not this PR's only when the default branch fails too"
require_text 'the PR is never widened to fix it' "a PR is never widened for a finding it did not cause"
require_text 'delegate-status issue-create --title' "the follow-up issue is filed once through the script"
require_text '<!-- delegator not-this-pr: <key> -->' "the PR says so once"
require_text 'Widen a PR to fix a finding or a failing check it did not cause' "the Never list forbids widening"
# An untracked AGENTS.md blocked worktree reclaim.
require_text 'agent scratch is not stray work: an untracked `AGENTS.md`' "agent scratch does not block reclaim"
require_text 'A modified tracked file, anywhere, still keeps the worktree.' "real changes still keep a worktree"
require_script 'SCRATCH_RE=' "the script knows agent scratch"
# Walkthroughs graded both themes and ran for non-rendering diffs.
require_text 'where the stack skill has a *Themes* rule, that rule picks the themes; both themes only without one' "the project's Themes rule picks the themes"
require_text '`Walkthrough: n/a — no rendered change`' "a non-rendering diff skips the walkthrough explicitly"
require_text '`rendered change: yes`' "the implementer reports whether the diff renders"
# Measure it.
require_text 'delegate-status cost-note <PR> --tool-calls' "every session writes its cost note"
require_text '`delegate-status cost-note` then appends the cost line as the body'"'"'s last line; a later body edit keeps it.' "the PR body ends with the cost line"
require_text 'Write the cost note (`references/handoff.md`) last, after steps 11 and 13 have finished editing the body.' "Work writes the cost note after every other body edit"
require_script 'cmd_cost()' "the script sums cost notes"

# Local suites duplicated CI: the implementer, the repair round and Land each
# ran the complete suite, and CI ran it twice more. CI is the full-suite gate;
# a project can still ask for a local run.
require_text '| `local_full_suite` | off |' "the local full suite is off by default"
require_text 'run lint, typecheck, build and the tests of the packages the diff touches, plus the mutation gate on the diff' "the implementer runs the affected scope"
require_text 'Do not run the complete test suite: CI runs it on the PR.' "the implementer leaves the full suite to CI"
require_text 'When the complete suite runs locally, the brief adds:' "a project can ask for the local full suite"
require_text '`local_full_suite` is on, or a changed file matches a `full_suite_paths` glob' "full_suite_paths turns the local full suite on for its paths"
require_text 'the same checks as step 6, limited to the files its fix touched' "the repair round checks only what the fix touched"
require_text 'If you changed no files, run nothing: step 7'"'"'s CI wait is the gate.' "Land reruns checks only when its review changed files"
reject_regex 'Where the self-check or gate requires the complete test suite, run it once' "the implementer no longer runs the full suite by default"

# Land re-reviewed the whole diff the human had just approved. It simplifies
# the diff, and reviews only what it wrote itself: a conflict resolution.
require_text 'Run `<simplify>` on the diff against `origin/<default branch>`.' "Land simplifies the whole diff"
require_text 'also run `<correctness_review>` on the conflict resolution only' "Land reviews only its own conflict resolution"
reject_regex 'Run `/code-review` at medium effort and `/simplify` on the diff' "Land no longer re-reviews the approved diff"
require_text 'Apply only changes that preserve behaviour; do not change any test'"'"'s assertions.' "Land's changes still preserve behaviour"
require_text 'Do not fix anything that needs a behaviour change: return it instead.' "Land still returns behaviour-changing findings"
require_text 'If test files changed, run the project'"'"'s `tdd-guardian` agent (else a subagent that loads the `tdd-guardian` skill) on the staged diff' "Land runs tdd-guardian only when tests changed"

# The walkthrough booted Docker, auth and the dev servers for test-only and
# data-layer diffs under the UI root, graded every item in both themes, and
# booted the stack a second time for the repair round's after-screenshots.
require_text '| `walkthrough_paths` | the UI root, minus `**/*.test.*`, `**/*.spec.*` and `**/__tests__/**` |' "walkthrough_paths defaults to the UI root without tests"
require_text 'a changed file matches `walkthrough_paths`' "the walkthrough triggers on walkthrough_paths"
require_text 'A test-only diff matches none of the defaults' "a test-only diff never boots the stack"
reject_regex 'contains a path under the project'"'"'s UI root' "the walkthrough no longer triggers on any UI-root path"
require_text 'the Checklist sections and themes its **Scope** step selects' "the walkthrough grades only the relevant sections"
require_text 'leave it running for step 9'"'"'s re-walk' "the stack stays up for the repair round"
require_text 're-walks them on the stack it left running' "the re-walk does not boot the stack again"
reject_regex 'it boots and signs in per the Recipe, re-walks' "the repair round no longer reboots the stack"
require_text 'send the walkthrough subagent one message to stop the stack' "a run never leaves the stack running"

# Claude Code on the web blocks GitHub GraphQL, and `gh pr`, `gh issue`,
# `gh label` and `gh repo view` are GraphQL underneath, so 4.26.0 failed on
# its first call there. The references make every GitHub write through
# delegate-status or `gh api` REST, and never name a GraphQL-backed command.
for f in "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references/*.md; do
  if grep -E '`gh (pr|issue|label|repo view)[ `]|gh api graphql|addPullRequestReviewThreadReply' "$f" | grep -vq '^- Call GraphQL: '; then
    fail "$(basename "$f") names no GraphQL-backed gh command"
  else
    pass "$(basename "$f") names no GraphQL-backed gh command"
  fi
done
require_text 'Call GraphQL: `gh pr`, `gh issue`, `gh label`, `gh repo view`, `gh api graphql`.' "the Never list forbids GraphQL"
require_text 'delegate-status reply <PR> <thread> --body-file <file>' "thread replies go through the REST replies endpoint"
require_text 'delegate-status pr-create --head <branch> --title "<subject>" --body-file <file>' "Work opens its PR over REST"
require_text 'delegate-status comment N --body-file <file>' "issue comments go over REST"
require_text '1. `delegate-status to-draft <PR>`.' "Bail-out returns the PR to draft over REST"
require_text 'is briefed with `delegate-status`'"'"'s absolute path and `--repo`' "subagents that write to GitHub can reach the script"

# Efficiency. A Run pass read work.md (the largest reference) even when Watch
# found nothing and the budget was at its limit; Reclaim, which every pass
# needs, now lives on its own.
if grep -Fq '| **Run** | `references/run.md`, `references/watch-digest.md`, `references/watch.md`, `references/reclaim.md` and `references/pick.md`; `references/work.md` once Pick finds one |' "$CORE"; then
  pass "a Run pass reads work.md only once Pick finds a candidate"
else
  fail "a Run pass reads work.md only once Pick finds a candidate"
fi
require_text 'Only when Pick returns a candidate, read `references/work.md`' "run.md defers work.md"
reject_regex 'Work\*\* step 2'"'"'s Reclaim' "nothing sends a pass to work.md for Reclaim"
# get_session ran once per /loop pass; the id is the session's, not the run's.
require_text 'Call `get_session` once per session, not once per run' "the cloud session id is fetched once per session"
require_text 'write the id to `ccr-session-id` in the session'"'"'s scratch directory' "the cloud session id survives /loop passes"
# On the web, PR events wake the session instead of a minute-by-minute poll.
require_text 'subscribe each delegated PR once' "Watch subscribes delegated PRs where the tool exists"
require_text 'Otherwise leave a background poll running between passes' "the CLI keeps the background poll"
require_text 'with `gh api` REST calls only' "the poll runs over REST"
require_text 'Subscribe the PR as **Watch** step 6 says' "Work subscribes the PR it opens"

# A delegated PR that fell into a merge conflict sat Idle until the human
# marked it ready, so Watch now syncs it, resolving only textual conflicts,
# and tells the human once per head when it cannot.
require_text '**Conflicted** (`conflicted`)' "Watch classes a PR with a merge conflict"
require_text 'Then run **Sync** on each Conflicted PR.' "Watch syncs conflicted PRs"
require_text 'Sync never touches a **Ready** PR' "Sync leaves a Ready PR to Land"
require_text 'dispatch **Land** step 4'"'"'s sync subagent with its brief unchanged' "Sync resolves only the textual conflicts Land may"
require_text 'Abort the in-progress merge (`git merge --abort`) and push nothing.' "Sync pushes nothing on a semantic conflict"
require_text '<!-- delegator sync: conflict <sha> -->' "Sync marks the head whose conflict it reported"
require_script '<!-- delegator sync: conflict ' "the script reads the sync marker"
require_text 'When step 4 returned `conflict`, the line `<!-- delegator sync: conflict <sha> -->`' "a Land bail-out on a conflict stops Sync retrying it"
require_script 'mergeable: .mergeable' "the script reads mergeability"

# Questions shape the questions after them, so a design conversation needs
# rounds, not one question per pass; a human in the session answers them in
# minutes, an issue in hours. Whatever the channel, the outcome lands on the
# issue, because state comes from GitHub alone.
require_text 'load `grilling` and run it in the chat' "a human-started Work grills in chat"
require_text 'A Work that **Pick** or **Run** started never grills in the chat' "an unattended Work keeps its questions on the issue"
require_text 'every question that depends on no unanswered one, each with your recommended answer' "a question comment carries a whole round with recommendations"
require_text 'post the decisions and the derived criteria' "chat decisions land on the issue"
# Confirmed criteria move into the body so they sit at the top of the issue.
require_text 'delegate-status promote-criteria N <comment id>' "confirmed criteria are promoted into the body"
require_script 'cmd_promote_criteria' "the script promotes criteria"
# Progressive disclosure. Every mode loaded the whole 35-50 KB skill, a quiet
# Watch pass included. The core keeps what every mode needs; each entry point
# lives in its own reference file, which the core's index names.
for section in '## Parameters' '## Delegator marker' '## Claims' '## Stop rule' '## Entry points' '## PR body contract' '## Never'; do
  if grep -Fxq -- "$section" "$CORE"; then
    pass "the core keeps $section"
  else
    fail "the core keeps $section"
  fi
done
# The core is what every mode loads, a quiet Watch pass included.
core_bytes="$(wc -c < "$CORE" | tr -d ' ')"
if [ "$core_bytes" -le 13000 ]; then
  pass "the core stays under 13 KB ($core_bytes bytes)"
else
  fail "the core stays under 13 KB ($core_bytes bytes)"
fi
if [ -x "$SKILL_DIR/scripts/delegate-status" ]; then
  pass "the bookkeeping script ships executable"
else
  fail "the bookkeeping script ships executable"
fi
for ref in pick work review watch run land sync blocked-and-oracle hand-back session reclaim tiers watch-digest handoff; do
  if [ -f "$SKILL_DIR/references/$ref.md" ] && grep -Fq -- "\`references/$ref.md\`" "$CORE"; then
    pass "references/$ref.md exists and the core's index names it"
  else
    fail "references/$ref.md exists and the core's index names it"
  fi
done
for entry in '### Pick' '### Work `#N`' '### Review `#PR`' '### Watch' '### Run' '### Land `#PR`' '### Blocked'; do
  if grep -Fxq -- "$entry" "$CORE"; then
    fail "the core no longer carries $entry"
  else
    pass "the core no longer carries $entry"
  fi
done

WALKTHROUGH="$REPO_ROOT/skills/delivery/browser-ux-walkthrough/SKILL.md"
if grep -Fq -- 'A caller that must not write production code' "$WALKTHROUGH"; then
  pass "the walkthrough lets a no-code caller skip its Fix step"
else
  fail "the walkthrough lets a no-code caller skip its Fix step"
fi

require_walkthrough() {
  local pattern="$1" label="$2"

  if grep -Fq -- "$pattern" "$WALKTHROUGH"; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_walkthrough '3. **Scope.**' "the walkthrough scopes the checklist to the change"
require_walkthrough '| Copy only (' "copy-only changes have a scope row"
require_walkthrough '| Style or token (' "style or token changes have a scope row"
require_walkthrough 'Both themes only when the scope is **Style or token**' "both themes only for style or token changes"
require_walkthrough 'Sections skipped:' "the output names the skipped sections"
require_walkthrough 'test files (`*.test.*`, `*.spec.*`, `__tests__/**`) are not UI files' "test files never trigger a walkthrough"
require_walkthrough 'Stop the stack once' "the stack is stopped once"
require_walkthrough 'If the stack skill has a *Themes* rule' "the stack skill's Themes rule picks the themes"
require_walkthrough 're-walks the affected surfaces on the running stack' "a no-code caller re-walks without a second boot"

echo ""

if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed${NC}"
