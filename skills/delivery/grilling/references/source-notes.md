# grilling: source notes

Adapted from Matt Pocock's `grilling`.

## Source

- Repository: <https://github.com/mattpocock/skills>
- Pinned revision: [`7739eaed`](https://github.com/mattpocock/skills/tree/7739eaed7f8f3915437a8def198a6d0d7206dbc7)
- Folder: [`skills/productivity/grilling`](https://github.com/mattpocock/skills/tree/7739eaed7f8f3915437a8def198a6d0d7206dbc7/skills/productivity/grilling)
- Licence: MIT, Copyright (c) 2026 Matt Pocock. The full notice is in
  [`../LICENSE`](../LICENSE).

## Taken

- `SKILL.md` and `agents/openai.yaml`, near verbatim: the design tree, rounds over the frontier, numbered questions with recommended answers, facts found by the agent and decisions put to the user.
- The fact-finding subagent starting with a fresh context window (upstream `7739eaed`, 2026-10-29).

## Changed (Richard Allen, 2026-10-08)

- Sub-agent wording made harness-neutral: look facts up yourself where the harness has no subagents.
