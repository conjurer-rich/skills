# @conjurer-rich/skills

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
