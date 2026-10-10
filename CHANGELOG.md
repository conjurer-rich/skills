# @conjurer-rich/skills

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
