# Watch digest

A `/loop` pass that finds nothing to do should cost almost nothing. `/delegate` runs `delegate-status watch-digest` before it loads this skill, and ends an unchanged pass without reading any reference file. This file says what the digest compares and what a full pass records.

**What it compares.** One REST sweep, no classification: for each open `<branch_prefix>` PR, its head SHA, draft state, whether it is in conflict, and the id of the newest issue comment, review comment and review that needs an answer (see **Delegator marker**). The delegator's own replies, claims, heartbeats and hand-offs carry the marker, so they are never news. For a Run loop it also takes each open `<label>` issue's comment count, labels and body length. A Watch-only loop passes `--prs-only`.

**The baseline.** `<scratch>/delegator/watch-digest.json`, in the session's scratch directory and outside any one run's directory, so every pass of the session finds it. A full pass records it with `watch-digest --state <file> --record` as **Watch** step 1, before it reads anything else. Recording at the start, not the end, means a comment that arrives during the pass is news to the next one; the cost is one extra full pass after the delegator pushes, because a new head is news too.

**The answer.** Without `--record`, the digest prints:

- `changed: true` with `reasons` (`PR #20: new comment or review`, `PR #23: marked ready`, `issue #31 changed`, `no baseline yet`): run the full pass. It leaves the baseline alone.
- `changed: true` with `full pass due: claim_ttl since the last one`: run the full pass. The digest cannot see a claim lapse, a 👍 on derived criteria or a CI result, so a full pass runs at least that often.
- `changed: false`: nothing an entry point acts on has moved. `/delegate` ends the pass as its **Idle pass** rule says.

**Backoff.** `next_interval_minutes` is 10 after a full pass and doubles with each idle pass in a row: 20, 40, then 60 at most. A full pass resets it. Pass `--interval` and `--max-interval` only when the project's delegation file sets a different loop interval.
