# Sync `#PR`

Merge the default branch into a delegated PR that has a merge conflict, resolving the conflict only when it is textual. Sync never touches a **Ready** PR: Land brings that one up to date itself. Anything Sync may not resolve goes to **Bail-out**, which tells the human once per head.

1. **Eligibility.** The head branch must start with `<branch_prefix>`; if not, say so and stop. Then claim the PR (**Claims**); if another session holds it, stop. Run `delegate-status pr <PR>`. If its `class` is `ready`, say Land brings a Ready PR up to date and stop. If `conflicted` is not true, say the PR has no conflict (or GitHub has not computed it yet, `mergeable: null`) and stop. Watch runs Sync only on class `conflicted`; a human-started Sync also runs when `sync_marker.current` is true, as a retry. Once the claim is yours, set the **Session title** to `Sync PR #P <PR title>`.
2. **Worktree.** Find or create the branch's worktree as in **Review** step 2.
3. **Merge.** Renew the claim, then dispatch **Land** step 4's sync subagent with its brief unchanged. It returns `merged`, `resolved` with the files, or `conflict` with the conflicting files. On `conflict`, go to **Bail-out** naming them. On `merged` (GitHub's conflict was stale), go to step 5.
4. **Check the resolution.** Renew the claim, then dispatch one subagent with `subagent_type: general-purpose`, `model: opus`, `run_in_background: true`, with the Work step 6 brief shape, the PR title and body, the resolved files, and these instructions. Its completion notice resumes this Sync.

   > Work only inside `<worktree path>`. Run `/code-review` at medium effort on the conflict resolution only: the resolved files, compared with both sides of the merge (`git diff --cached -- <files>` and `git diff MERGE_HEAD -- <files>`). Change nothing. Then run the project's pre-push checks at Work step 6's scope (lint, typecheck, build and the tests of the packages the resolved files belong to; the complete suite only when `local_full_suite` is on). Do not commit. Return: (a) every finding, with file and line, (b) the verification commands and their last ten lines.

   If (a) is not empty, or the checks fail, go to **Bail-out** with the findings.
5. **Commit and push.** Commit without asking. Confirm the claim is still yours, then dispatch the ship subagent (**Work** step 10's brief without PR creation): after a resolved conflict it commits the merge with the project's co-author trailer (git made the commit already on `merged`); then `git push`, with no force flag; it returns the new head SHA. Post a PR comment with `delegate-status comment <PR> --body-file <file>`: `Merged <default branch> in <sha> to clear a merge conflict.`, the resolved files, and the delegator marker. With `land` on, a draft stays a draft: the human's Ready click approves the merge with the rest of the diff.
6. Release the claim with the reason `synced`. Report the new head SHA and stop.

## Bail-out

1. Clean up the worktree through the ship subagent; the delegator runs no git command in it. Abort the in-progress merge (`git merge --abort`) and push nothing.
2. Post one PR comment with `delegate-status comment`, containing:
   - the Sync step that stopped and the reason, in one sentence;
   - the conflicting files, or the findings, as a list;
   - `Resolve the conflict, or push any commit, and the next Watch pass tries again.`
   - the line `<!-- delegator sync: conflict <sha> -->`, where `<sha>` is the PR's current `headRefOid`, then the delegator marker.

   The sync marker makes `delegate-status` class this head `idle`, so Watch does not retry and comment again on every pass. A new head clears it.
3. Release the claim with the reason `conflict needs the human`, and stop. Sync changes no draft state.
