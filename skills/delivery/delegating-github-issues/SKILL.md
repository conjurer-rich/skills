---
name: delegating-github-issues
description: Take a triaged GitHub issue end-to-end to a reviewable pull request in an isolated worktree, then address review comments on request. With the land parameter on, also review, simplify and merge one the human marked Ready for review. Use when a project command such as /delegate asks to pick up an issue, work a specific issue number, address review comments on a PR the delegator opened, watch delegated PRs, sync or land one, or run one unattended pass that watches and then picks and works the next issue (for example under `/loop /delegate`). Not for triage, merging PRs the delegator did not open, or writing production code in the calling session.
---

# Delegating GitHub issues

You are the delegator. You do not write production code. You decide eligibility, budget, claims, acceptance criteria, the size check and tier, and deferrals, and you write the PR body and commit message files. Bootstrap, implementation, the independent checks, the walkthrough and evidence pushes are subagents' jobs under the **Hand-back contract**; you read their verdicts, not their output. Commit, push, PR creation and the CI wait are fixed commands you run yourself, output to a file. You never enter a worktree. A human reviews. With `land` on, the delegator also merges, but only a PR the human marked Ready for review, only through **Land**.

## Parameters

The calling command supplies these; defaults apply when it does not, and keep the behaviour from before a parameter existed.

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
| `implementer_model_small` | `sonnet` | Implementer for expected tier S |
| `implementer_model_large` | `opus` | Implementer otherwise |
| `full_suite_paths` | none | Globs that, when a diff touches one, make the implementer run the complete suite locally |
| `local_full_suite` | off | When on, the implementer also runs the complete test suite locally; off, CI runs it on the PR |
| `preflight` | none | The project's drift fixers, from a `preflight:` line; the implementer runs them before a PR's first push |
| `walkthrough` | off | When on, run `browser-ux-walkthrough` when a changed file matches `walkthrough_paths` |
| `walkthrough_paths` | the UI root, minus `**/*.test.*`, `**/*.spec.*` and `**/__tests__/**` | Globs of user-visible UI files; a glob starting with `!` excludes |
| `oracle` | off | When on, apply the Preview oracle rule |
| `land` | off | When on, Work opens drafts, and **Land** may merge a PR the human marked Ready for review |
| `claim_ttl` | 45 minutes | A claim with no heartbeat for this long lapses, and another session may take the item |
| `progress_label` | `in-progress` | Carried by an item while a session holds a live claim on it, so a human sees an agent is on it |

A **Verification scope** section in the project's delegation file replaces the `pre_pr_gate`'s complete-suite rule (`references/tiers.md`).

## Delegator marker

The delegator posts through the human's `gh` auth, so a comment's author cannot tell the two apart. Every comment and thread reply the delegator posts therefore ends with `<!-- delegator -->`. Other agent sessions post through the same auth with the Claude Code footer (`[Claude Code](https://claude.`) instead.

A comment **needs an answer** when it does not contain `<!-- delegator`, it does not contain the Claude Code footer (another agent posted it, not the human), its author login does not end in `[bot]` (nor is a GitHub App), it does not contain `<!-- preview-`, and nothing answers it. A later comment with either marker in the same review thread answers an inline comment. A PR comment containing `<!-- delegator reply-to: <comment id> -->` answers a top-level comment or review body; Land's own status comments answer nothing. `delegate-status` computes this.

## Claims

Several delegator sessions can run at once through one `gh` login, so a session claims an issue (Work) or PR (Review, Land, Sync) with a comment before it changes anything. The claim comment is the lock: it ends `<!-- delegator claim: <session> -->`, it is live while its heartbeat is within `claim_ttl`, and the live claim with the lowest comment id wins, so two sessions that claim at once agree on one winner. `<progress_label>` only tells humans: the winner adds it and every release removes it, and it never decides who holds an item.

**Session name.** Before its first claim, a session names itself with 8 random hex characters. It is not the **Session title**; the two never mix.

**`delegate-status`.** `scripts/delegate-status`, in this skill's directory, runs the claims and every fixed query and prints one JSON line. Run it from the main checkout with `--repo <owner>/<repo> --session <session>` and each parameter the project changed (`--label`, `--rank-labels`, `--prefix`, `--progress-label`, `--claim-ttl <seconds>`, `--max-worktrees`, `--max-open-prs`, `--land on`). Keep claim ids in `claims.json` in the run's scratch directory. On a non-zero exit, report its last line and stop. It also makes every GitHub write outside git, and waits for CI, over REST: Claude Code on the web blocks GraphQL.

- **Claim.** `claim <n>` prints `won` with the `id` (and `open_pr` when a delegated PR is open for the issue). When another session holds a live claim, it posts nothing, prints `lost` with the `holder` and exits 4; in a race, the loser deletes its own claim comment and exits 4. On exit 4, stop work on the item, never retry or take over; a human-started entry point says `#<n> is claimed by delegator session <holder>`. It reuses this session's live claim, so a session never claims an item twice. The winner adds the label, creating it if missing; Never `--force`.
- **Heartbeat.** After a won claim, run `heartbeat <n> <id>` as a background task until you release. It renews every 15 minutes; when it exits 4 the claim is lost, so stop work on the item.
- **Confirm.** `confirm <n> <id>` prints `live` or `lost`. Confirm before any push, PR creation or merge. On `lost`, write nothing more to the item, report it lost to the holder, and leave staged work in the worktree.
- **Renew.** `renew <n> <id>` confirms, then rewrites the claim's first line to end `renewed <UTC time>`. A lapsed claim keeps its low id, so renewing it blindly would take the item back from the session that claimed it since: a lapsed claim prints `lost` and nothing is written. Renew in place of Confirm before every push and before a hand-off; without a heartbeat, also before each long step (Work steps 6–9, Review step 5, Land steps 5 and 7, Sync steps 3 and 4).
- **Release.** Every stop releases the claim with `release <n> <id>`, which removes the label first. A stop that posted nothing else on the item deletes the claim comment (`--delete`); any other stop rewrites it (`--reason "<one-line reason>"`) as ``Released by delegator session `<session>`: <reason>.`` and `<!-- delegator claim-released: <session> -->`. It refuses a comment that is not this session's.

A Land waiting on a background task has not stopped: its claim, heartbeat and label hold. Review steps inside Land use Land's claim. The human frees a claim by deleting it.

**Stale label.** `stale_label` marks an item that carries `<progress_label>` with no live claim, left by a crashed session. Pick and Watch remove it with `clear-label <n>`, which refuses while a claim is live, then treat the item as free.

## Stop rule

Every turn re-reads the whole context, so sessions stay short, and a session works **one issue**: once it has worked one, it never picks another.

- **Hand-off threshold**: context use above 50 %, more than 80 tool calls in the main session, or a finished Work. Finish the current item to its next checkpoint (PR opened or pushed, claim released), then stop and hand off.
- **Hard stop**: context use above 80 %, more than 150 tool calls, or the same isolation-guard refusal three times. Stop at once; staged work stays in the worktree.

Either way, follow `references/handoff.md`. It then follows **Hand-off**, under `/loop` or not. The counters live in `run-state.json`.

## Entry points

Read only the reference files for the entry point you are running. Paths are relative to this skill's directory.

| Entry point | Read |
|---|---|
| **Pick** | `references/pick.md` |
| **Work** `#N` | `references/work.md` and `references/tiers.md` |
| **Review** `#PR` | `references/review.md`, `references/tiers.md` and `references/work.md` (its steps 5–10: bootstrap, handoff, checks, walkthrough, repair round, ship) |
| **Watch** | `references/watch-digest.md`, `references/watch.md` and `references/reclaim.md`, then the files for any Review, Land or Sync it runs |
| **Run** | `references/run.md`, `references/watch-digest.md`, `references/watch.md`, `references/reclaim.md` and `references/pick.md`; `references/work.md` once Pick finds one |
| **Land** `#PR` | `references/land.md`, `references/review.md` (its step 2, and steps 4–6 when step 3 has review to answer), `references/reclaim.md` and `references/work.md` (its steps 5, 6 and 10) |
| **Sync** `#PR` | `references/sync.md`, then step 4 of `references/land.md`, step 2 of `references/review.md` and steps 5, 6 and 10 of `references/work.md` |
| **Blocked**, **Preview oracle rule** | `references/blocked-and-oracle.md`, when Work or Review sends you there or `oracle` is on |
| **Hand-back contract** | `references/hand-back.md`, before any dispatch or ship |
| **Session title**, **Running in a cloud container** | `references/session.md` |
| **Stop rule** reached, **Hand-off**, cost note | `references/handoff.md` |

## PR body contract

Use these eight headings, in this order, every time. A section that does not apply says why in one line; it is never omitted. **Work** step 10 says what each carries.

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

End with the project's PR footer. `delegate-status cost-note` then appends the cost line as the body's last line; a later body edit keeps it.

## Never

- Add `<label>` to an issue, resolve a review thread, force-push, or rebase a pushed branch.
- Merge a PR, except through **Land** with `land` on.
- Mark a PR ready for review; only the human does. `delegate-status to-draft` is the delegator's one draft-state change.
- Call GraphQL: `gh pr`, `gh issue`, `gh label`, `gh repo view`, `gh api graphql`.
- Remove a worktree whose PR has not merged, or delete any branch other than the local `<branch_prefix>` branch of a worktree being reclaimed — and that one only with `git branch -d`.
- Kill a process to free a worktree directory; report the leftover path instead.
- Edit or delete another session's claim. A session touches only its own claim comments.
- Enter a worktree, or run any git command inside one beyond those `references/hand-back.md` lists.
- Read a subagent's diff, screenshot, browser snapshot, test log or report body into the main context; read its verdict table or findings list from the file instead.
- Fork the conversation into a subagent; every brief is self-contained.
- `git stash`, `git commit --amend` on a pushed branch, or `git branch -D`.
- Re-run, or hand to another agent, a command that a subagent's own permission system refused: a refusal is an answer, not an obstacle.
- Put a model identifier in anything pushed: commit messages, PR titles or bodies, comments or code.
- Work a second issue in the same session, before or after the first one's PR opens; run another session instead.
- Put `<progress_label>` on an item without holding a live claim on it, or leave it on one you released.
- Run the full test suite locally unless `local_full_suite` is on or the diff touches a `full_suite_paths` glob, and never at the repository root in the foreground or to check a single change.
- Point a browser at a deployed preview URL.
- Continue after an ambiguous review comment without the human's answer.
- Widen a PR to fix a finding or a failing check it did not cause (`references/review.md`).
