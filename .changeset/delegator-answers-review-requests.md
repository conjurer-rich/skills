---
"@conjurer-rich/skills": minor
---

delegating-github-issues: the delegator now answers `review-requests` findings. Before, it skipped every comment with the Claude Code footer, and that included every `review-requests` review. A submitted review whose body carries the `review-requests head:` marker now counts. Each inline comment that opens a thread with a `blocking` or `should fix` finding needs an answer until someone replies to it. So does the review body, when its `## Not placed on a line` section lists such a finding. `delegate-status pr` lists these as `kind: thread` or `kind: review` items marked `review_requests: true`, and the Watch digest counts them as news. **Watch** therefore starts a Review on its own, and with `rereview` on that Review re-requests the reviewer. Every other agent's comment is still skipped.

A new parameter, `answer_review_requests` (`blocking` by default, or `all`), decides whether `consider` findings count too. `delegate-fire` and `delegate-loop` pass it to the gate.
