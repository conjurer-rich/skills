# Blocked and the Preview oracle rule

## Blocked

Push whatever is staged as a draft PR, through the ship subagent under the Hand-back contract: commit with subject `[blocked] <issue title> (#N)` after approval (without asking when **Run** started this Work), `git push -u origin <branch>` with no force flag, `delegate-status pr-create --draft --head <branch> --title "[blocked] …" --body-file <file>` with the gate output in the **Verification** section, then comment the PR URL on the issue with `delegate-status comment N --body-file <file>`: the one-line reason under `## Blocked`, ending with the delegator marker. The subagent returns the PR URL and the comment id, nothing more. Then stop.

## Preview oracle rule

Read the sticky: `gh api repos/<owner>/<repo>/issues/<PR>/comments --jq '.[] | select(.body | contains("<!-- preview-e2e -->")) | .body'`.

- Contains `preview-e2e: pass` → note it in the PR body's **Preview E2E** section.
- Contains `preview-e2e: network-boundary` → leave the PR alone; the auto-retry owns it.
- Contains `preview-e2e: playwright-failure` → `delegate-status to-draft <PR>`, then comment on the PR (`delegate-status comment`) naming the failing spec from the sticky and the most likely cause from the diff.
- Sticky absent after the wait → say so and stop.
