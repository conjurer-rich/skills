# Blocked and the Preview oracle rule

## Blocked

Push whatever is staged as a draft PR, inline as the **Hand-back contract** ships: commit with subject `[blocked] <issue title> (#N)` after approval (without asking when **Run** started this Work), `git push -u origin <branch>` with no force flag, `delegate-status pr-create --draft --head <branch> --title "[blocked] …" --body-file <file>` with the gate output and every blocking finding that remains, written as **Fix options** below, in the **Verification** section, then comment the PR URL on the issue with `delegate-status comment N --body-file <file>`: the one-line reason under `## Blocked`, ending with the delegator marker. A finding or check that is not this PR's (`references/review.md`) never sends a run here. Set `worked_issue` and, while `ticket` is set, the `ticket`'s `pr` in `run-state.json` and on the issue (`delegate-status ticket set N --pr <P> --chain <chain>`), write the cost note (`references/handoff.md`), then stop. The prefix comes off with `delegate-status review-status` after a Review round that leaves no blocking finding, or at the latest with `delegate-status merge`; the delegator renames it nowhere else.

### Fix options

The session that hit the block knows the findings best, so it writes how to fix each one, and a one-line reply from the human unblocks the PR. Number each blocking finding that remains (`1.`, `2.`, …), name its check and location, then give either:

- numbered options (`1a`, `1b`, …), each with a one-line trade-off, and exactly one marked **(recommended)**; or
- `single fix: <the fix>` in place of options when only one sensible fix exists, so "fix all" is unambiguous.

Add a `defer to a follow-up issue` option only where **Work** step 9 allows deferral: a walkthrough or whole-diff finding outside the acceptance criteria. Never offer it for an unmet acceptance criterion or a `tdd-guardian` finding.

End the list with a suggested reply built from the recommended options and single fixes, ready to paste:

```
1. <finding> (<check>, <file:line>)
   - 1a (recommended): <fix>. Trade-off: <one line>.
   - 1b: <fix>. Trade-off: <one line>.
   - 1c: defer to a follow-up issue. Trade-off: <one line>.
2. <finding> (<check>, <file:line>): single fix: <fix>.

Suggested reply: `1a, 2`
```

**Review** step 4 reads such a reply as actionable.

## Preview oracle rule

Read the sticky: `gh api repos/<owner>/<repo>/issues/<PR>/comments --jq '.[] | select(.body | contains("<!-- preview-e2e -->")) | .body'`.

- Contains `preview-e2e: pass` → note it in the PR body's **Preview E2E** section.
- Contains `preview-e2e: network-boundary` → leave the PR alone; the auto-retry owns it.
- Contains `preview-e2e: playwright-failure` → `delegate-status to-draft <PR>`, then comment on the PR (`delegate-status comment`) naming the failing spec from the sticky and the most likely cause from the diff.
- Sticky absent after the wait → say so and stop.
