# Tiers, verification scope and preflight

Read by **Work** and **Review**. Every rule here reads the project's delegation file; a project that defines none of these keys gets the defaults in the core's **Parameters** table.

## Tier

The tier sets how much process a diff gets. It is measured once the staged diff exists, in **Work** step 7, from the implementer's (g) and its list of changed files, never from a guess:

- **S**: at most `tier_small_max_lines` changed lines, at most `tier_small_max_packages` packages (a package is the nearest directory above a changed file that holds a `package.json`, or the repository root), and no changed file matching a `risk_paths` glob. A diff that touches any `risk_paths` glob is never tier S. `tier_small_max_lines: 0` turns tier S off.
- **L**: a diff that touches a `risk_paths` glob, or changes more than four times `tier_small_max_lines` lines.
- **M**: everything else.

M and L run the same checks; the letter tells the human how closely to read. Record the tier and its measurement in the PR body's **Summary**. For example: `Tier S: +83/−4, 1 package, no risk path`.

**Expected tier.** Before the handoff, **Work** step 4 also names the tier it expects from the issue and the size check. An expected tier S brief tells the implementer: no separate plan document, no planning or progress-tracking agent run; keep the change to the criteria. The expected tier also picks the implementer's model (`implementer_model_small` for S, `implementer_model_large` otherwise). The measured tier still decides step 7; a diff that grows out of tier S just gets the tier M checks.

**What tier S changes.**

| | Tier S | Tier M or L |
|---|---|---|
| Plan document | none | as the project's workflow asks |
| Independent checks (Work step 7) | one self-contained reviewer that also checks the criteria and re-measures the tier | `tdd-guardian`, `acceptance-review` and the whole-diff review, in parallel |
| Verification | the project's **Verification scope** | the project's **Verification scope** |

No tier skips independent verification, and RED-before-GREEN evidence goes in the PR body at every tier.

## Verification scope

When the project's delegation file has a **Verification scope** section, it replaces the `pre_pr_gate`'s complete-suite rule (for `pr-readiness.md`, the complete non-watch test gate in its §3) and this skill's default scope. Copy the section verbatim into every implementer, repair-round and Land brief, and the implementer follows it in place of the gate's suite step. Without one, the default holds: lint, typecheck, build and the tests of the packages the diff touches, plus the mutation gate on the diff; CI runs the complete suite on the PR.

Either way, the implementer also runs the complete suite locally, once, at the end, when `local_full_suite` is on or a changed file matches a `full_suite_paths` glob.

The PR body's **Verification** section opens with the scope it followed, `Verification scope: project` or `Verification scope: default`, plus `, full suite: <reason>` when the complete suite ran, then lists the exact commands and their last lines.

## Preflight

A `preflight:` line in the project's delegation file names the project's own drift fixers, as commands in order, separated by `;` or as a list (for example, a generated-file follower then the lint fixer). The skill hard-codes no fixer.

Before a PR's first push, the implementer runs each preflight command in order from the worktree root, after its last code change and before its final verification, so the checks cover what the fixers changed. It stages what they changed with `git add -u` and lists any new untracked file in its report instead of adding it. A preflight command that fails is a `blocked` return with its last line. Review and Sync, which push to an existing PR, run no preflight. Without a `preflight:` line there is no preflight step.
