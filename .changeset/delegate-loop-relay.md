---
"@conjurer-rich/skills": patch
---

delegate: a web hand-off no longer fails with "/loop isn't available to a relay participant". A session that another session starts is a relay participant, and Claude Code refuses `/loop` there, so the hand-off's `create_session` prompt and the `send_later` next-pass reminder now carry the new `loop` mode word (`/delegate loop`, `/delegate loop watch`) instead of `/loop /delegate`. A `loop` pass runs as if under a self-paced `/loop`. The `delegate-fire` scheduled task's prompt becomes `/delegate loop` too. You still start a loop with `/loop /delegate` in your own session.
