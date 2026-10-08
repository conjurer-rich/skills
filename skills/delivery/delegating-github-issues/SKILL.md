---
name: delegating-github-issues
description: Take a triaged GitHub issue end-to-end to a reviewable pull request in an isolated worktree, then address review comments on request. Watch delegated PRs and sync one that has a merge conflict. With the land parameter on, also review, simplify and merge one the human marked Ready for review. Use when a project command such as /delegate asks to pick up an issue, work a specific issue number, address review comments on a PR the delegator opened, watch delegated PRs, sync or land one, or run one unattended pass that watches and then picks and works the next issue (for example under `/loop /delegate`). Not for triage, merging PRs the delegator did not open, or writing production code in the calling session.
---

# Delegating GitHub issues

You are the delegator. You do not write production code, and you do no mechanical work in your own context: subagents do it under the **Hand-back contract**, and you read their verdicts, not their output. You decide eligibility, budget, claims, acceptance criteria, the size check and tier, and deferrals, and you write the PR body and commit message files. Bootstrap, implementation, the independent checks, the walkthrough, commit, evidence push, PR creation and issue comments are each a subagent's job. You never enter a worktree. A human reviews. With `land` on, the delegator also merges, but only a PR the human marked Ready for review, only through **Land**.

The **Stop rule** ends a run before it fills its context.

## Parameters

The calling command supplies these; defaults apply when it does not.

| Parameter | Default | Meaning |
|---|---|---|
| `label` | `agent-ready` | Only issues with this label are eligible |
| `rank_labels` | `p1`, `p2` | Higher rank first; unranked last |
| `max_worktrees` | 1 | Active `<branch_prefix>` worktrees. Parallelism comes from running several `/loop /delegate` sessions, each claiming its own issue; it does not come from one session working several issues. |
| `max_open_prs` | 6 | Open PRs in the repository, all authors |
| `branch_prefix` | `delegated/` | Prefix of every delegated branch |
| `pre_pr_gate` | the project's `/pr` command | The gate the implementer passes before the PR opens |
| `tier_small_max_lines` | 150 | Most changed lines (insertions plus deletions) a tier S diff may have; `0` turns tier S off |
| `tier_small_max_packages` | 1 | Most packages a tier S diff may touch |
| `risk_paths` | none | Globs a tier S diff may not touch: migrations, the riskiest packages |
| `local_full_suite` | off | When on, the implementer also runs the complete test suite locally; off, CI runs it on the PR |
| `walkthrough` | off | When on, run `browser-ux-walkthrough` when a changed file matches `walkthrough_paths` |
| `walkthrough_paths` | the UI root, minus `**/*.test.*`, `**/*.spec.*` and `**/__tests__/**` | Globs of user-visible UI files; a glob starting with `!` excludes |
| `oracle` | off | When on, apply the Preview oracle rule |
| `land` | off | When on, Work opens drafts, and **Land** may merge a PR the human marked Ready for review |
| `claim_ttl` | 4 hours | A claim not renewed for this long lapses, and another session may take the item |
| `progress_label` | `in-progress` | Carried by an item while a session holds a live claim on it, so a human sees an agent is on it |

## Delegator marker

The delegator posts through the human's `gh` auth, so a comment's author cannot tell the two apart. Every comment and thread reply the delegator posts therefore ends with `<!-- delegator -->`. Other agent sessions post through the same auth with the Claude Code footer (`[Claude Code](https://claude.`) instead.

A comment **needs an answer** when it does not contain `<!-- delegator`, it does not contain the Claude Code footer (another agent posted it, not the human), its author login does not end in `[bot]` (nor is a GitHub App), it does not contain `<!-- preview-`, and nothing answers it. A later comment with either marker in the same review thread answers an inline comment. A PR comment containing `<!-- delegator reply-to: <comment id> -->` answers a top-level comment or review body; Land's own status comments answer nothing. `delegate-status` computes this.

## Claims

Several delegator sessions can run at once through one `gh` login, so a session claims an issue (Work) or PR (Review, Land) with a comment before it changes anything. The claim comment is the lock: it ends `<!-- delegator claim: <session> -->`, it is live while updated within `claim_ttl`, and the live claim with the lowest comment id wins, so two sessions that claim at once agree on one winner. `<progress_label>` only tells humans: the winner adds it and every release removes it, and it never decides who holds an item.

**Session name.** Before its first claim, a session names itself with 8 random hex characters. It is not the **Session title**; the two never mix.

**`delegate-status`.** `scripts/delegate-status`, in this skill's directory, runs the claims and every fixed query and prints one JSON line. Run it from the main checkout with `--repo <owner>/<repo> --session <session>` and each parameter the project changed (`--label`, `--rank-labels`, `--prefix`, `--progress-label`, `--claim-ttl <seconds>`, `--max-worktrees`, `--max-open-prs`, `--land on`). Keep claim ids in `claims.json` in the run's scratch directory. On a non-zero exit, report its last line and stop. It also makes every GitHub write outside git, and waits for CI, over REST: Claude Code on the web blocks GraphQL.

- **Claim.** `claim <n>` prints `won` with the `id` (and `open_pr` when a delegated PR is open for the issue), or `lost` with the `holder`. It reuses this session's live claim, so a session never claims an item twice. The loser deletes its own claim comment; a human-started entry point says `#<n> is claimed by delegator session <holder>` and stops. The winner adds the label, creating it if missing; Never `--force`.
- **Confirm.** `confirm <n> <id>` prints `live` or `lost`. Confirm before any push, PR creation or merge. On `lost`, write nothing more to the item, report it lost to the holder, and leave staged work in the worktree.
- **Renew.** `renew <n> <id>` confirms, then rewrites the claim's first line to end `renewed <UTC time>`. A lapsed claim keeps its low id, so renewing it blindly would take the item back from the session that claimed it since: a lapsed claim prints `lost` and nothing is written. Renew only right before a long step, Work steps 6, 7, 8 and 9, Review step 5, Land steps 5 and 7, Sync steps 3 and 4, so each starts with a whole `claim_ttl`. The implementer handoff is the longest; a project whose handoffs can outlast `claim_ttl` raises it. A lapse is still caught by the next Confirm.
- **Release.** Every stop releases the claim with `release <n> <id>`, which removes the label first. A stop that posted nothing else on the item deletes the claim comment (`--delete`); any other stop rewrites it (`--reason "<one-line reason>"`) as ``Released by delegator session `<session>`: <reason>.`` and `<!-- delegator claim-released: <session> -->`. It refuses a comment that is not this session's.

A Land waiting on a background task has not stopped: its claim and label hold. Review steps inside Land use Land's claim. A crashed session's claims lapse after `claim_ttl`; the human frees one sooner by deleting it.

**Stale label.** `stale_label` marks an item that carries `<progress_label>` with no live claim, left by a crashed session. Pick and Watch remove it with `clear-label <n>`, which refuses while a claim is live, then treat the item as free.

## Stop rule

A run stops, stops any walkthrough stack it left running, releases its claims and reports when any of these holds: the harness reports context use above 80 %, the run has made more than 150 tool calls in the main session, or the same isolation-guard refusal has occurred three times. The report names the step reached, the worktree path, what is staged there and what the next session should do first. Staged work stays in the worktree. Under `/loop` it then follows **Hand-off**: a wakeup here would trip the rule again.

The counters live in `run-state.json` in the run's scratch directory: `tool_calls` (the delegator's own calls in the main session; a subagent's calls do not count), `guard_refusals` (keyed by the refused command), `step`, `issue`, `worktree`, and the **Session title** state `title` and `ccr_session_id`. The delegator rewrites the file at the start of every numbered step and after every refusal, so a wakeup can read where the stopped run got to without replaying it. Three refusals of the same command mean the command is wrong for this environment, not that a fourth phrasing will pass.

## Entry points

Read only the reference files for the entry point you are running. Paths are relative to this skill's directory.

| Entry point | Read |
|---|---|
| **Pick** | `references/pick.md` |
| **Work** `#N` | `references/work.md` |
| **Review** `#PR` | `references/review.md` and `references/work.md` (its steps 5–10: bootstrap, handoff, checks, walkthrough, repair round, ship) |
| **Watch** | `references/watch.md` and `references/reclaim.md`, then the files for any Review, Land or Sync it runs |
| **Run** | `references/run.md`, `references/watch.md`, `references/reclaim.md` and `references/pick.md`; `references/work.md` once Pick finds one |
| **Land** `#PR` | `references/land.md`, `references/review.md` (its step 2, and steps 4–6 when step 3 has review to answer), `references/reclaim.md` and `references/work.md` (its steps 5, 6 and 10) |
| **Sync** `#PR` | `references/sync.md`, then step 4 of `references/land.md`, step 2 of `references/review.md` and steps 5, 6 and 10 of `references/work.md` |
| **Blocked**, **Preview oracle rule** | `references/blocked-and-oracle.md`, when Work or Review sends you there or `oracle` is on |
| **Hand-back contract** | `references/hand-back.md`, before dispatching any subagent |
| **Session title**, **Hand-off**, **Running in a cloud container** | `references/session.md` |

## PR body contract

Use these eight headings, in this order, every time. A section that does not apply says why in one line; it is never omitted.

```markdown
## Summary
## Acceptance criteria
## TDD evidence
## Mutation gate
## Verification
## UX walkthrough
## Found on the way, not fixed here
## Preview E2E
```

`Summary` links the issue (`Closes #N`) and names the tier with its measurement (`Tier S: +83/−4, 1 package, no risk path`). `Acceptance criteria` lists each criterion with the test name that proves it. `TDD evidence` and `Mutation gate` carry what the implementer returned. `Verification` carries the exact commands and their last lines. `UX walkthrough` carries the walkthrough skill's output, `Walkthrough blocked: …`, or `Not applicable: no changed file matches walkthrough_paths`. `Found on the way` lists observations and any `follow-up` issues filed. `Preview E2E` carries the oracle state or `Oracle off: informational until #<oracle issue> merges`. End with the project's PR footer.

## Never

- Add `<label>` to an issue, resolve a review thread, force-push, or rebase a pushed branch.
- Merge a PR, except through **Land** with `land` on.
- Mark a PR ready for review; only the human does. `delegate-status to-draft` is the delegator's one draft-state change.
- Call GraphQL: `gh pr`, `gh issue`, `gh label`, `gh repo view`, `gh api graphql`.
- Remove a worktree whose PR has not merged, or delete any branch other than the local `<branch_prefix>` branch of a worktree being reclaimed — and that one only with `git branch -d`.
- Kill a process to free a worktree directory; report the leftover path instead.
- Edit or delete another session's claim. A session touches only its own claim comments.
- Enter a worktree, or run any git command inside one beyond `git worktree add`, `git worktree list`, `git worktree remove`, `git worktree prune` and `git -C <path> status --porcelain`.
- Read a subagent's diff, screenshot, browser snapshot, test log or report body into the main context; read its verdict table or findings list from the file instead.
- `git stash`, `git commit --amend` on a pushed branch, or `git branch -D`.
- Re-run, or hand to another agent, a command that a subagent's own permission system refused: a refusal is an answer, not an obstacle.
- Put a model identifier in anything pushed: commit messages, PR titles or bodies, comments or code.
- Work a second issue in the same session while one is in progress; run another session instead.
- Put `<progress_label>` on an item without holding a live claim on it, or leave it on one you released.
- Run the full test suite locally unless `local_full_suite` is on, and never at the repository root in the foreground or to check a single change.
- Point a browser at a deployed preview URL.
- Continue after an ambiguous review comment without the human's answer.
