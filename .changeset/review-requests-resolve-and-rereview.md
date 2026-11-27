---
"@conjurer-rich/skills": minor
---

review-requests: a new `resolve_fixed_threads` setting (off by default) lets a re-review resolve the threads the skill opened once the new commits fix them. It resolves only when the code confirms the fix and no reply waits for an answer. It resolves on submit with `post: comment`, and under `post: pending` it lists what you would resolve. A re-review now opens with an **Earlier findings** section that marks each earlier finding fixed, still open or answered without a change. Where no route can resolve a thread (the GitHub MCP server, else `gh api graphql`), it reports "would resolve" and does not fail.

delegating-github-issues: a new `rereview` parameter (off by default). After Review answers a blocking or should-fix thread from a `review-requests` review, it re-requests that reviewer (`delegate-status rereview --request`). With a roster, `delegate-fire` routes the `review_requested` event to the reviewer's optional `review_url` trigger. A re-review that leaves no blocking or should-fix thread open ends the exchange.
