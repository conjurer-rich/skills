---
"@conjurer-rich/skills": patch
---

delegating-github-issues: a session subscribes only to the PRs it holds (the PR its Work opened, a PR it is running Review, Land or Sync on, and a PR a hand-off names to it) and unsubscribes when it stops holding the PR, or the PR merges or closes. Every other delegated PR is covered by the digest the next pass reads. The hand-off unsubscribes only the held PRs and names them in the new session's system prompt, so the new session subscribes to exactly those. This stops the subscription and notification floods that forced watcher compactions.
