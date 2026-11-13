---
"@conjurer-rich/skills": minor
---

Add `/review-requests`: drafts a review of every open pull request that asks for your review (or one named PR) on the `review` skill's Standards and Spec axes plus the harness's correctness reviewer, and leaves it on GitHub as your own pending review to edit and submit. It never approves, requests changes or pushes, treats PR content as untrusted data, and can keep the queue drafted under `/loop`.
