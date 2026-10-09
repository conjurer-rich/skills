---
name: delegate
description: Keep delegating under /loop (watch delegated PRs, then pick and work the next issue), or work a labelled GitHub issue to a reviewable PR, pick the next one, address review comments, watch delegated PRs, or land a PR marked ready
disable-model-invocation: true
argument-hint: "[run] | #<issue> | next | review #<pr> | watch | land #<pr> | sync #<pr>"
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(pnpm:*), Bash(npm:*), Bash(npx:*), Bash(timeout:*), Bash(jq:*), Bash(tail:*), Bash(*/delegating-github-issues/scripts/delegate-status:*), Agent, SendMessage, mcp__claude-code-remote__get_session, mcp__claude-code-remote__set_session_title, mcp__claude-code-remote__subscribe_pr_activity, mcp__claude-code-remote__unsubscribe_pr_activity, mcp__claude-code-remote__create_session, mcp__claude-code-remote__send_later, mcp__claude-code-remote__delete_trigger
---

Current branch:
!`git branch --show-current`

Repository:
!`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null || echo "unknown: no origin remote"`

Project delegation settings (`.claude/delegation.md`):
!`cat "$(git rev-parse --show-toplevel 2>/dev/null)/.claude/delegation.md" 2>/dev/null || echo "none"`

Bookkeeping script:
!`find ~/.claude/skills ~/.claude/plugins -path '*/delegating-github-issues/scripts/delegate-status' -type f 2>/dev/null | sort -V | tail -n 1 | grep . || echo "none"`

Claude Code fills in the four blocks above before this skill loads. In another harness they arrive unfilled: run the commands yourself (`git branch --show-current`, `git remote get-url origin`, read `.claude/delegation.md` at the repository root), and use `../delegating-github-issues/scripts/delegate-status` beside this skill as the bookkeeping script. Outside Claude Code, prefer the runner, `scripts/delegate-loop` in that skill, to `/loop`.

## Settings

If the settings above read `none`, reply "This project has no `.claude/delegation.md`, so `/delegate` is not set up here. Add one with a **Parameters** table for the `delegating-github-issues` skill and a **Project rules** list." and stop. Never guess a project's settings.

Otherwise the settings file's **Parameters** table sets the skill's parameters; any parameter it leaves out takes the skill's default. The skill's defaults are `max_worktrees` 1, `max_open_prs` 6, `branch_prefix` `delegated/`, `pre_pr_gate` the project's own pre-PR gate if it has one, else the `mutation-testing` skill's `references/pr-readiness.md`, `claim_ttl` 45 minutes, `progress_label` `in-progress`, `tier_small_max_lines` 150, `tier_small_max_packages` 1, no `risk_paths`, no `full_suite_paths`, no `preflight`, `implementer_model_small` `sonnet`, `implementer_model_large` `opus`, `review_model` `opus`, `mechanical_model` `haiku`, `correctness_review` `/code-review` at medium effort, `simplify` `/simplify`, `walkthrough_paths` the UI root without test files, and `local_full_suite`, `walkthrough`, `oracle` and `land` off. A `preflight:` line in the settings file sets `preflight`, and a **Verification scope** section replaces the `pre_pr_gate`'s complete-suite rule. A project that defines none of these gets the skill's behaviour from before they existed. `max_worktrees` is 1 because one session works one issue; parallelism comes from running several `/loop /delegate` sessions, each claiming its own issue, and a project that raises it pays in that session's context. Its **Project rules** apply inside every delegated run. Owner and repo come from the **Repository** line above: strip any `https://github.com/` or `git@github.com:` prefix and `.git` suffix. A value in the settings file wins over it.

## Mode

Parse the arguments given with the skill (`$ARGUMENTS` in Claude Code):

- No arguments, or `run` → one **Run** pass: Watch, then Pick and Work. Run it as `/loop /delegate` to keep delegating until something needs the human. Several sessions can run `/loop /delegate` at once: each claims an issue or PR before touching it and labels it with the skill's `progress_label` while it holds the claim, and the others skip it. An idle pass costs one digest call (**Idle pass**), and the loop backs off from 10 to 60 minutes while nothing changes. One pass works at most one issue through to its PR.
- `#<n>` or a bare number → **Work** issue `n`.
- `next` → **Pick**, then **Work** the result.
- `review #<n>` or `review <n>` → **Review** PR `n`.
- `watch` → one **Watch** pass. Run it as `/loop /delegate watch` to keep watching.
- `land #<n>` or `land <n>` → **Land** PR `n`.
- `sync #<n>` or `sync <n>` → **Sync** PR `n`: merge the default branch into a delegated PR with a merge conflict. Watch runs it on its own.
- Anything else → print the seven forms above and stop.

## Model

The `/loop /delegate` session mostly routes: it runs `delegate-status`, reads verdict lines and dispatches subagents, and it writes no production code. It can run on a cheaper model than the work it hands out; choose one with `/model` before starting the loop. Land's review subagent (Land step 5) and Sync's resolution check run on `review_model` (default `opus`) whatever the session runs on. The implementer (Work step 6) runs on `implementer_model_small` (default `sonnet`) when Work expects tier S and on `implementer_model_large` (default `opus`) otherwise, escalating once to the large model if the small one is blocked or its diff is not tier S. Mechanical subagents (bootstrap, evidence, cleanup) run on `mechanical_model` (default `haiku`), and every other subagent runs at its own default. This is a recommendation for the human: the command pins no model, so a session that needs judgement it cannot give can be switched without editing anything.

## Idle pass

A **Run** or **Watch** pass under `/loop` first asks whether anything changed, before it loads the skill. Skip this section when the **Bookkeeping script** line reads `none`, or the mode is anything else.

1. Run `<script> watch-digest --repo <owner>/<repo> --state <scratchpad>/delegator/watch-digest.json`, with `--prs-only` for **Watch**, and `--label`, `--prefix` and `--claim-ttl <seconds>` when the settings change them. `<scratchpad>` is this session's scratch directory.
2. If it prints `changed: true`, or exits non-zero, go on to **Procedure**.
3. If it prints `changed: false`, end the pass without loading the skill: when `run-state.json` (under `<scratchpad>/delegator/<session name>/`) holds a `next_pass_trigger` whose `next_pass_at` is still in the future, cancel it with `delete_trigger`; schedule the next pass `next_interval_minutes` out (on the web `send_later` with that `delay_minutes`, the exact `/loop` command as `message`, `name` `delegate next pass` and `initiation` `own_followup`, writing its `trigger_id` and `fire_at` back to `run-state.json`; on the CLI `ScheduleWakeup`), and print one line: `idle: no change since <since>; next pass in <next_interval_minutes> min`. Nothing else.

## Procedure

Load the `delegating-github-issues` skill and follow the named entry point with the parameters above, reading only the reference files its **Entry points** index names for that mode.

These rules apply in every project, alongside its Project rules:

- Wait for commit approval before every commit in **Work** or **Review** started by hand. **Run**, **Watch**, the **Work**, **Review** and **Land** runs they start, and `land #<n>` commit without asking.
- **`delegate-status`** (skill): claims, reclaim, the budget count, Pick's eligibility and Watch's PR classification run through the skill's `scripts/delegate-status`, which prints one line of JSON; the delegator never re-derives them with its own `gh` and `jq` calls. The same script makes the GitHub writes (comments, thread replies, PR creation and edits, back to draft, merge) and the CI wait over REST, because Claude Code on the web blocks GitHub GraphQL and with it `gh pr`, `gh issue`, `gh label` and `gh repo view`.
- **Hand-back contract** (skill): every subagent writes its report to a file and returns at most ten lines; the delegator never reads a diff, screenshot, snapshot or log, never enters a worktree, and never runs `agent-browser`.
- **Session title** (skill): the chat is named after the last issue or PR the session worked on (`#N <issue title>`, `PR #P (#N) …` once Work opens the PR, `Review PR #P …`, `Land PR #P …`), and keeps that name after the claim is released, so the human can find which session handled each PR in the sidebar or the `/resume` picker. Only a session that has not worked an item yet is named `/delegate watching <owner>/<repo>`. The rename never stops a run.
- **Stop rule** (skill): sessions stay short. A session works one issue, and hands off once that issue's PR opens or it passes 50 % context or 80 main-session tool calls, after finishing the current item to a checkpoint; it stops at once at 80 %, 150 calls or the third identical isolation-guard refusal. It leaves a `<!-- delegator:handoff -->` comment on the PR (done, next step, verified commands, open threads, traps) for the next session to read instead of re-deriving. On Claude Code on the web, the command moves to a new session with an empty context (**Hand-off**), under `/loop` or not, so delegating carries on without the human starting one; elsewhere the run or loop ends and the human starts a fresh session.
- **Claims** (skill): `delegate-status claim` exits 4 when another session holds a live claim; the run stops there, and never retries or takes the item over. A won claim keeps a heartbeat running, and lapses 45 minutes after its last beat.
- Commit trailer `Co-Authored-By: <the model running this delegation> <noreply@anthropic.com>`. Name the model that actually did the work, not a fixed one, or the attribution is false the first time a different model runs `/delegate`. PR footer `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

The final line of the run is the PR URL, the merge SHA, the Run or Watch pass report, the idle line, or the one-line reason the run stopped. Every delegated PR body ends with a `Delegation cost:` line (sessions, tool calls, hand-offs); `delegate-status cost` sums it over recent merged PRs.
