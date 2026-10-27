# @conjurer-rich/skills

## 5.10.0

### Minor Changes

- e4b1dbb: Add `/delegate-spawn`, which a scheduled task runs to restart `/loop /delegate` chains in free lease slots while eligible issues wait, and `delegate-status lease status`, a read-only count of live and free chain slots.

## 5.9.1

### Patch Changes

- b45504d: delegating-github-issues: a PR the **Blocked** step opened no longer keeps its `[blocked]` title after it is unblocked. `delegate-status review-status` takes the prefix off in the same write as the status line, since a Review round only reaches it once the gate passed with no blocking finding left, and reports `unblocked: true` when it did. `delegate-status merge` drops the prefix from the squash subject and the merged PR, so it never reaches the default branch. Before this, nothing renamed the PR: merged and ready-for-review PRs still read `[blocked]`, while the derived labels said the opposite.

## 5.9.0

### Minor Changes

- 424fed5: delegating-github-issues: a delegator chain now owns one ticket until it is complete, by default. This changes the default behaviour of `/loop /delegate` and `scripts/delegate-loop`; there is no opt-out.

  - The ticket (issue and PR numbers) is kept as `ticket` in `run-state.json` and carried, with the chain's name, to the session a hand-off creates, which resumes it. While the ticket is open the chain never runs Pick, runs Review, Sync and Land only on its own PR and subscribes only to that PR. Once the PR merges or closes, or the human releases the ticket (by removing the eligibility label from its issue, or deleting its ticket marker), the next pass picks as before.
  - The ticket is also recorded on the issue as a ticket marker comment, which other chains honour whether or not the owning chain's lease slot is live: `delegate-status status` reads an issue another chain holds as `ticketed`, and Pick skips it. Only a marker posted by the delegator's own login counts. A marker with no PR lapses 12 hours (`--ticket-ttl`) after its last renewal. Only a chain sets a ticket: a Work started by hand (`/delegate #N`) posts no marker, and reports an issue another chain holds as its ticket. New `delegate-status ticket set|renew|heartbeat|release` commands and a `--chain` option manage it; `ticket renew` and `ticket heartbeat` refuse (exit 4, writing nothing) a marker that has lapsed or that another chain's ticket now stands beside.
  - `delegate-status next-action` takes `--ticket <n> [--pr <p>]`, or adopts a marker of this chain that `status` finds on an issue, with or without a PR (so a chain that lost `run-state.json` or `ticket.json` resumes its ticket), and then answers for that ticket alone: Watch work on its PR, a resumed Pick of its issue (idle at the budget limit), or idle while it waits. It reports the ticket as complete when its PR merges or closes or its issue leaves the label.
  - A chain about to wait on the human or on CI hands off first. On the CLI, where no hand-off is possible, it waits in place under the ticket's background poll instead of ending the loop. The waiting chain sets no scheduled wakeup, except on the web a 4-hourly safety-net reminder while the ticket has no PR yet, since nothing else wakes the session when the human answers on the issue.
  - `scripts/delegate-loop` keeps the chain's ticket in `ticket.json` in its state directory, hands it to each pass and to the gate, renews a PR-less ticket's marker, and drops it once the ticket is complete. Parallelism comes only from `max_chains`.

## 5.8.0

### Minor Changes

- 751a035: python: a new skill for writing, reviewing and refactoring Python 3.12+. It follows the repository's own tools first (with uv, ruff, pyright strict and pytest as defaults, and a complete `pyproject.toml` in `references/tooling.md`), and covers strict typing, parsing untrusted data into typed models at the boundary, one owner per value set, `NewType` identifiers, frozen dataclasses, Protocols, error handling, UTF-8 I/O and aware datetimes, async and pytest. `engineering-practice` gains a Python section that routes to it, and `ask` lists it beside `typescript-strict`. A `python` quality suite under `evals/skills` (four cases, proven against a reference solution) measures the skill; `run-quality.sh` now builds a fixture with `uv sync --locked` when it has a `uv.lock`.

### Patch Changes

- b85fbce: `scripts/install-global` now works from a clone without symlink support (Git Bash on Windows without developer mode). Codex's and OpenCode's `AGENTS.md` used to receive the single word `CLAUDE.md`, because such a clone checks the `global/AGENTS.md` symlink out as a plain file. Every target now comes from `global/CLAUDE.md`, and `global/AGENTS.md` is gone. The script checks once whether symlinks work and copies when they do not, so a re-run reports those copies as current instead of backing them up and copying them again; where symlinks work, a copy left by `--copy` is still replaced by a link. `scripts/*` is now checked out with LF endings, so a Windows clone keeps the CR out of their shebangs, and `test/run.sh` gets further on Windows: `check-portability.py` reports paths with `/`, the version-sync and eval checks pass paths to Node as arguments, and `upstream-changes` prints UTF-8.
- c5b5b04: `tdd-guardian` no longer forks when a subagent loads it, so a delegator's Process check reviews the pack it was briefed with instead of a PR it guessed. With no scope given, the skill asks or names the scope it chose on the first line of its report. The delegator's Process-check briefs now tell the reviewer to apply the checklist in its own context.

## 5.7.0

### Minor Changes

- ee6c2d7: delegating-github-issues: a `[blocked]` PR, and a failed repair round under Watch or Land, now writes each remaining blocking finding as **Fix options**: numbered options (`1a`, `1b`, …) with a one-line trade-off and one marked **(recommended)**, or `single fix:` when only one fix makes sense, plus a `defer to a follow-up issue` option where deferral is allowed (never for unmet acceptance criteria or `tdd-guardian` findings). The list ends with a ready-to-paste suggested reply such as `1a, 2, 3 defer`. Review treats a reply naming option ids, or "fix all" when every finding is a single fix, as actionable, and copies the chosen options verbatim into the implementer brief.
- 859c27b: delegating-github-issues: dispatches now use four narrow agent types shipped in `agents/` (`delegate-implementer`, `delegate-reviewer`, `delegate-walkthrough`, `delegate-mechanical`) instead of `general-purpose`. Each carries only the tools its role uses, so a subagent's first turn costs about half as many tokens; the reviewer has no edit tool and, by instruction, uses write only for its report. Where the types aren't installed, the skill falls back to `general-purpose` with the same brief and model.
- 281636b: delegating-github-issues: a Run now takes one of `max_chains` chain slots (new parameter, default 1) before anything else, and exits at once with a one-line report when every slot is held by a live chain, so only the intended number of delegator chains run per repository. A new `delegate-status lease` subcommand takes, renews, heartbeats, releases and hands over the slots as claims on a tracking issue labelled `delegator-lease`; a hand-off passes the slot to the session it creates, so no third session can take it in between.
- 79cc020: delegating-github-issues: a review round costs the delegator one wake. Work step 7 dispatches its checks (and the walkthrough) together in the foreground and resumes once, when all have returned, and the skill sets no wakeup or reminder while a foreground subagent runs. A new `scripts/review-pack` writes the staged diff, the diffstat and the implementer's summary once to `<scratch>/<N>/review-pack.md`, and every reviewer reads that file instead of running `git diff`; `--base` packs a branch's diff for Land's review and `--merge` a conflict resolution against both sides for Land's and Sync's checks, and the Whole diff check applies `<correctness_review>`'s recipe to the pack rather than recomputing the diff. The Acceptance check runs on a new `acceptance_model` parameter, default `sonnet`. The delegator never waits in a polling or `sleep` loop: suite, mutation-gate, CI and Preview oracle waits go to a background task that wakes it on exit, or to a runner subagent at `mechanical_model` that returns pass or fail with the failing lines.
- da8ae13: delegating-github-issues: the UX walkthrough now runs on a new `walkthrough_model` parameter (default `sonnet`) instead of the session's model. browser-ux-walkthrough walks each screen in one shell call, with the snapshot and screenshot written to files rather than printed, and keeps screenshots at most 1024 px wide (a 1024 px viewport at device scale 1, or a downscale when an image tool is present) before reading them.

### Patch Changes

- 49a3b9c: delegating-github-issues: a session subscribes only to the PRs it holds (the PR its Work opened, a PR it is running Review, Land or Sync on, and a PR a hand-off names to it) and unsubscribes when it stops holding the PR, or the PR merges or closes. Every other delegated PR is covered by the digest the next pass reads. The hand-off unsubscribes only the held PRs and names them in the new session's system prompt, so the new session subscribes to exactly those. This stops the subscription and notification floods that forced watcher compactions.
- 54bbb5a: delegating-github-issues: a new reference page, `references/cloud-environment.md`, says how to build a cloud environment the delegator works well in: only the GitHub connector, network access to `api.github.com`, a copy-paste setup script that checks `gh`, `jq`, `git` and `python3` and enables `pnpm` only when it is missing, and a GitHub access check with `gh api repos/<owner>/<repo>` rather than `gh auth status`. `references/session.md` links to it.
- dc3c920: delegating-github-issues: the hand-off names a fresh `claude/delegate-handoff-<8 hex>` outcome branch that is absent from `origin`, so the cloud harness's stop hook no longer reports default-branch commits as unpushed and loops. A new optional `environment_id` parameter (default none) is passed to the hand-off session when set.

## 5.6.7

### Patch Changes

- 9f33614: delegating-github-issues: the implementer brief now says to read each file once, run filtered quiet tests with output sent to a file, and wait on long runs as background tasks instead of a polling or sleep loop. The repair round dispatches a fresh implementer with a findings brief rather than messaging the first one. Subagents return `blocked` when the stack a full-suite run needs is not up.

## 5.6.6

### Patch Changes

- e007fb6: `delegating-github-issues`: delegated PRs now show when they are waiting on you. `status --sync-labels` keeps a derived `awaiting-review` label (`--review-label`) on each delegated PR that no session is working on, has nothing left to answer, and whose current head you have not approved, and takes it off as soon as you comment. After each Review round, the new `delegate-status review-status` writes one line at the top of the PR body: the round, how many comments it addressed, the head commit and a link to the changes since your last review. GitHub never notifies you of work done through your own login, so these replace hunting through comments.

## 5.6.5

### Patch Changes

- f2eb4a4: `delegating-github-issues`: when you start a Work yourself and the issue needs a chain of dependent decisions (or asks "grill me"), the delegator now runs `grilling` with you in the chat, then posts the decisions and derived criteria on the issue for your 👍. An unattended Work still asks on the issue, but a question comment now carries a whole round: every independent question, each with a recommended answer you can accept with "yes". Once you 👍 derived criteria, the new `delegate-status promote-criteria` appends them to the issue body under `## Acceptance criteria`, so they sit at the top of the issue; your text and the comment are kept.

## 5.6.4

### Patch Changes

- 9d6aed8: `delegating-github-issues`: Pick now classifies an issue `blocked` while an issue or PR it depends on is still open. Blockers come from GitHub's native "blocked by" dependencies, a `## Dependencies` section, or `Blocked by #N` lines. Pick skips a blocked issue, and the issue frees itself once every blocker closes or merges. `status --sync-labels` keeps two derived labels in step with the classification: `needs-answer` (`--answer-label`) while the delegator waits on the human, and `blocked` (`--blocked-label`) while an issue is blocked. Both are recomputed every pass and never read as state.

## 5.6.3

### Patch Changes

- e20a6d5: `delegating-github-issues`: an unanswered **Question before delegation** now keeps an issue `waiting-on-human` even when it has acceptance criteria in its body or confirmed derived criteria, so Pick no longer offers an issue whose question the delegator is still waiting on. A bot comment after the question no longer counts as the human's answer. The human answers by replying; editing the issue body is not an answer.

## 5.6.2

### Patch Changes

- 2d74540: `delegating-github-issues`: the `pre_pr_gate` default no longer points at a `/pr` command that craft does not ship. It is now the project's own pre-PR gate if it has one, else the `mutation-testing` skill's `references/pr-readiness.md`. The PR body's **Summary** also gains a short view of the change (pseudocode, a call tree, a file tree or a diff sketch) and a merge-danger line (one-way or two-way door, blast radius).

## 5.6.1

### Patch Changes

- 75a0481: delegate-status passes comments, threads, reviews and timelines to jq through files (`--slurpfile`), so a PR or issue with more than 128 KB of comments no longer fails with "Argument list too long".

## 5.6.0

### Minor Changes

- 1bd8553: delegating-github-issues: run outside Claude Code (Phase 7b).

  - **`references/harness.md`** names each Claude Code capability the skill uses, and what to do without it:
    - **Subagents:** in another harness, a headless `codex exec` or `claude -p` per brief, or the brief carried out in order.
    - **Models** and **reviewers:** set by parameters (below).
    - **Scheduling, PR subscriptions, session titles and Hand-off:** skipped outside Claude Code and under `delegate-loop`.
  - **New parameters:**
    - `review_model` (default `opus`) and `mechanical_model` (default `haiku`) replace the pinned models.
    - `correctness_review` (default `/code-review` at medium effort; `codex review` in Codex) and `simplify` (default `/simplify`) replace the named built-ins.
  - **`/delegate` is now a user-invoked skill,** `delegate`. In Claude Code it works as before: its context lines are still filled in before it loads. In another harness it says how to gather that context itself, and points to `scripts/delegate-loop`.

## 5.5.0

### Minor Changes

- 3a0bcd0: delegating-github-issues: a harness-neutral runner, `scripts/delegate-loop`, beside `/loop /delegate`.

  - **`delegate-status next-action`** prints `watch`, `land`, `pick` or `idle` with its reasons. It is the zero-token gate: plain `gh` and `jq`, in Watch's order and then Pick.
  - **`scripts/delegate-loop --agent claude|codex|opencode`** asks the gate, sleeps while idle, and otherwise starts the CLI once per pass with `prompts/delegate-run.md`, in a fresh context. It reads the project's `.claude/delegation.md`, and claims under a stable session name. It stops on a STOP file or after a run of failures, and caps agent passes per day. It logs each pass and its token use to `.delegate-loop/`.

## 5.4.0

### Minor Changes

- d342fcd: Codex support. Install with `codex plugin marketplace add conjurer-rich/skills` then `codex plugin add craft@conjurer`; Codex reads the same `.claude-plugin/` manifests.

  - Every skill has an `agents/openai.yaml`. User-invoked skills and the Claude Code-only ones (`delegating-github-issues`, `browser-ux-walkthrough`) turn off Codex's implicit invocation.
  - `/plan` and `/continue` are now user-invoked skills, `plan` and `continue`, so they work in both harnesses. `/delegate` stays a Claude Code command.
  - The `tdd-guardian` and `refactor-scan` agents are now skills of the same name. In Claude Code they run in a forked subagent (`context: fork`); elsewhere they run inline. The delegator uses a project's own `tdd-guardian` agent when it has one, and the skill otherwise.
  - Each item has a portability tier (portable, degrades, claude-only) in `portability.json`. `craft:ask` marks the items that do not run, or run differently, in Codex.
  - New checks: `scripts/check-portability.py` keeps portable skills free of Claude Code tool names and `~/.claude` paths, and `scripts/check-codex-install.py` installs craft into a throwaway Codex home in CI and checks which skills the model is offered.

- 9dfac9c: delegating-github-issues: cut the token cost of delegated runs, and hand off every run at its limit (ported from the `.dotfiles` fork, PRs 44 and 48).

  - **Tiers and verification scope** come from the project's delegation file: `tier_small_max_lines`, `tier_small_max_packages`, `risk_paths`, the new `full_suite_paths`, and a **Verification scope** section, which replaces the `/pr` gate's complete-suite rule. Tier S writes no plan document and gets one self-review. The rules live in the new `references/tiers.md`. The expected tier also picks the implementer's model (`implementer_model_small` / `implementer_model_large`), with one escalation as before.
  - **Short sessions.** The Stop rule hands off at 50 % context, 80 tool calls, or once the session's one issue has a PR, under `/loop` or not, and links the new session. A hand-off leaves a `<!-- delegator:handoff -->` PR comment; `delegate-status pr` returns it as `handoff`. See `references/handoff.md`.
  - **Lean subagents.** Commit, push, PR creation and the CI wait run inline, with output in a log file. Every subagent gets a self-contained brief. Mechanical steps run on `model: haiku`.
  - **Cheap Watch.** `delegate-status watch-digest` lets `/delegate` end an unchanged pass before loading the skill; the interval backs off from 10 to 60 minutes.
  - **Claims.** `claim` refuses with exit 4 when another session holds a live claim. A background `heartbeat` keeps a claim live, and `claim_ttl` drops to 45 minutes.
  - **CI.** `checks <pr> --head <sha>` waits on that exact commit; `--table` prints failing jobs' annotations and log tails.
  - **Preflight.** A `preflight:` line lists the project's drift fixers, run before a PR's first push.
  - **Measure.** Each delegated PR body ends with a `Delegation cost:` line; `delegate-status cost` sums it.

## 5.3.0

### Minor Changes

- bb7b199: New skills adapted from Matt Pocock's `mattpocock/skills@b0618bc4` (MIT):

  - `review`: reviews a branch, PR or work in progress against a fixed point on two separate axes. **Standards** covers the repository's written standards, up to three craft skills chosen from the diff, and Fowler's smell baseline. **Spec** runs `acceptance-review` against the originating issue. Bugs stay with the harness's own reviewer (`/code-review`, `codex review`). `tdd-guardian` and `refactor-scan` now point at it for whole-PR review.
  - `grilling` (model-invoked), with the user-invoked entry points `/grill-me` (writes nothing) and `/grill-with-docs` (records settled terms through `ubiquitous-language` and decisions through the `adr` agent). Skills that used to say "`grill-me` when installed" now load `grilling`.
  - `writing-for-agents`: the guide for writing skills and `CLAUDE.md` / `AGENTS.md`; `retro` now always loads it.
  - `teach`: learn a topic over several sessions in a workspace in the current directory. It **replaces `teach-me`**, which is removed from the shelf.

- 63aa484: `delegating-github-issues`: the implementer's model now follows the tier Work predicts from the issue before handoff. A predicted tier S (clearly one package, no `risk_paths`; any doubt is not S) runs on `sonnet`; anything else runs on `opus` as before. A Sonnet implementer that returns `blocked`, or whose diff measures not S, is re-dispatched once on `opus` in the same worktree, briefed with the first attempt's outcome; it never steps down. Projects can change the models with the new `implementer_model_small` (default `sonnet`) and `implementer_model_large` (default `opus`) parameters. Land's reviewer and Sync's resolution check stay on `opus`.

## 5.2.0

### Minor Changes

- 1fd6a5b: Two new user-invoked skills, adapted from Matt Pocock's `ask-matt` and `retro` (MIT, `mattpocock/skills@b0618bc4`):

  - `/craft:ask` maps every craft skill, agent and command into flows (idea to ship, plus on-ramps for bugs, legacy code, upkeep and deploys) and lists shelved skills with when to promote them. CI now fails if a shipped item is missing from it; it is the only shipped file allowed to name a shelved item.
  - `/craft:retro` reviews a session and proposes changes to the environment: navigation pointers, automated checks, coding standards, steering files, tooling, information access, and a new **missed skills** category that compares the session against `craft:ask`'s map.

## 5.1.0

### Minor Changes

- f01dffc: `engineering-practice` now carries the engineering guidelines itself instead of pointing at a copy of the old `CLAUDE.md`. Policy lives in its `SKILL.md`; which skill to load for which work lives in `references/routing.md`, merged from both old routing lists and limited to skills that are shipped or marked "when installed".

  New `global/CLAUDE.md` (with `global/AGENTS.md` linked to it) and `scripts/install-global`, which links it to `~/.claude/CLAUDE.md` and, when Codex or OpenCode are installed, to their `AGENTS.md`. It backs up any existing file and retires the old `~/.claude/base-CLAUDE.md`. Run it once from a clone; `--copy` where symlinks are unavailable.

## 5.0.0

### Major Changes

- 5d6ece3: craft moves to its own repository, `conjurer-rich/skills`, and its own marketplace, `conjurer`.

  Reinstall it: `claude plugin uninstall craft@conjurer-dotfiles`, then `claude plugin marketplace add conjurer-rich/skills` and `claude plugin install craft@conjurer`. Skill, agent and command names are unchanged (`craft:<name>`).

  - Skills are grouped into `skills/engineering`, `architecture`, `delivery` and `writing`. Eleven unused items move to `shelf/`, which is kept in the repository but not installed: `bff-design`, `cli-design`, `graph-engineering`, `panel-review`, `production-parity-skill-builder`, `render-code-shape`, `teach-me`, the `docs-guardian`, `progress-guardian`, `ts-enforcer` and `use-case-data-patterns` agents, and `/setup`. `folder-structure` is deprecated.
  - The PR-readiness evidence model moves from `panel-review` to `mutation-testing/references/pr-readiness.md`.
  - `engineering-practice` reads its guidelines from its own `references/guidelines.md`.
  - The Stop hook ships with the plugin (`hooks/hooks.json`) instead of being installed into `settings.json`.
  - `LICENSE` keeps Paul Hammond's notice and adds Richard Allen's; `ACKNOWLEDGEMENTS.md` lists every adapted source.
