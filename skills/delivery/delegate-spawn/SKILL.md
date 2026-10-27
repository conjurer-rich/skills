---
name: delegate-spawn
description: Start /loop /delegate chains in free lease slots while eligible issues wait, at most spawn_per_fire per run; meant to be fired by an hourly scheduled task on Claude Code on the web
disable-model-invocation: true
allowed-tools: Read, Bash(git:*), Bash(jq:*), Bash(*/delegating-github-issues/scripts/delegate-status:*), mcp__claude-code-remote__get_session, mcp__claude-code-remote__create_session, mcp__claude-code-remote__set_session_title
---

Repository:
!`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null || echo "unknown: no origin remote"`

Project delegation settings (`.claude/delegation.md`):
!`cat "$(git rev-parse --show-toplevel 2>/dev/null)/.claude/delegation.md" 2>/dev/null || echo "none"`

Bookkeeping script:
!`find ~/.claude/skills ~/.claude/plugins -path '*/delegating-github-issues/scripts/delegate-status' -type f 2>/dev/null | sort -V | tail -n 1 | grep . || echo "none"`

Claude Code fills in the three blocks above before this skill loads. In another harness they arrive unfilled: run the commands yourself, and use `../delegating-github-issues/scripts/delegate-status` beside this skill as the bookkeeping script. Starting a session needs Claude Code on the web's `create_session`; elsewhere, run `scripts/delegate-loop` in the `delegating-github-issues` skill instead.

You are the delegator spawner. A `/loop /delegate` chain hands itself on from session to session, but some exits end it for good (a `full` lease, a failed hand-off, a session the human closed), and nothing starts a new one. You keep the running chains at `max_chains` while eligible work waits. You never pick, claim or work an issue yourself, and you never load the `delegating-github-issues` skill.

Nobody answers prompts here. End with exactly one report line.

## Settings

If the settings or the bookkeeping script read `none`, report `spawner: not set up (<which one is missing>)` and stop.

If this session has no `create_session` tool (Claude Code on the web's session tools), report `spawner: not set up (no create_session; attach the Claude Code Remote connector to the scheduled task)` and stop. Check this before any `lease` call: a slot taken with nobody to hand it to sits idle until `claim_ttl`.

Owner and repo come from the **Repository** line: strip any `https://github.com/` or `git@github.com:` prefix and `.git` suffix. From the settings file's **Parameters** table, read `max_chains` (default 1), `max_open_prs`, `max_worktrees`, `label`, `land` and `spawn_per_fire` (default 1). Pass the first five to every `delegate-status` call that takes them (`--max-chains`, `--max-open-prs`, `--max-worktrees`, `--label`, `--land`), and `--claim-ttl <seconds>` when the settings change `claim_ttl`. `<status>` is the bookkeeping script and `<scratch>` is this session's scratch directory.

## Procedure

1. **Work.** `<status> status --repo <owner>/<repo> <flags> > <scratch>/status.json`, then `<status> next-action --repo <owner>/<repo> --from <scratch>/status.json`. Read `counts.free` (0 when absent) from the status file with `jq`. On a non-zero exit, report `spawner: status failed: <last line>` and stop.
   - `idle`: report `spawner: idle (<reasons>)` and stop.
2. **Capacity.** `<status> lease status --repo <owner>/<repo> --max-chains <max_chains>`. It needs no session and writes nothing.
   - `free` 0: report `spawner: full (<holders>)` and stop.
   - `pick`: `want` = `min(spawn_per_fire, counts.free, free)`.
   - `watch` or `land`: `want` = 1 when `live` is 0. Otherwise report `spawner: <action> left to the running chains` and stop: a live chain's **Watch** answers the review or lands the PR.
3. **Take a slot.** Name this session `spawner-<8 random hex>` once. Run `<status> lease take --repo <owner>/<repo> --session <name> --max-chains <max_chains>`.
   - Exit 5 (`full`): another session took the last slot since step 2. Stop and report.
   - `won`: keep its `id` and `slot`.
4. **Hand it to a new chain.** Name the successor with 8 random hex characters, then run `<status> lease hand <id> --to <successor> --repo <owner>/<repo> --session <name> --max-chains <max_chains>`. The successor's first `lease take` finds the slot already its own, and no third session can take it in between. If it exits 4, the slot was lost: report it and stop.
5. **Start the chain.** Pick an `outcome_branch` of `claude/delegate-handoff-<8 hex>` for which `git ls-remote --exit-code origin refs/heads/<branch>` exits 2. Call `get_session` with no arguments once for this session's id. Then call `create_session` once, with:
   - `prompt`: `/loop /delegate`
   - `source_url`: the main checkout's `origin` URL, with no `source_revision`
   - `outcome_branch`: the branch picked above
   - `title`: `/delegate watching <owner>/<repo>`
   - `append_system_prompt`: `Delegator hand-off from session <this session id> after spawn at step spawner; session name <successor>.`

   Pass `environment_id` when the settings set it; otherwise leave it out so the chain inherits this environment. Always leave `model` unset. If the call fails, report it and stop; the handed slot lapses after `claim_ttl`.
6. **Repeat** steps 3–5 until `want` chains have started.
7. **Title and report.** Set this session's title to `[spawner] started <k>`, or `[spawner] <idle|full>` when it stopped earlier; a failed rename never stops the run. Then report one line: `spawner: started <k> chain(s) (<links as [<last 8 of id>](https://claude.ai/code/<session id>)>); slots <live + k>/<max_chains>; <counts.free> free issues`.

## Scheduling

Run it from a scheduled task that starts a fresh session on each firing, with the prompt `/delegate-spawn` (`/craft:delegate-spawn` when the plugin is installed), hourly. Attach the repository and the Claude Code Remote connector, which supplies `create_session`; a scheduled task made from inside a session may carry neither, so check both in the scheduled task's settings. Most firings stop at step 1 or 2 and write nothing. A firing's fixed cost is the session's system prompt and every attached connector's tools, so attach no other connectors, and give the scheduled task an environment with only the GitHub connector (`../delegating-github-issues/references/cloud-environment.md`).

| Lever | Effect |
|---|---|
| `max_chains` | The WIP limit, and so the ceiling on parallel spend |
| `spawn_per_fire` | The ramp: at 1, an empty board refills one chain per firing, not all at once |
| Cadence | The longest a free slot waits before it is refilled |
| `max_open_prs` | When reviews back up, `budget.at_limit` turns `pick` into `idle`, so no chain is started for work nobody can review |
| Disabling the scheduled task | Running chains carry on; no new ones start |

## Never

- Claim, label, comment on or work an issue or PR.
- Delete or edit a lease comment that this session did not post.
- Start a chain while `next-action` says `idle`, or more than `spawn_per_fire` chains in one run.
- Retry `lease take` after `full`, or retry a failed `create_session`.
