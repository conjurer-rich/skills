# Restarting chains with delegate-fire

Advice to the human, not instructions to the delegator. Set this up when `/loop /delegate` runs on Claude Code on the web and you want chains that ended to restart on their own.

## Why it exists

A chain hands itself on from session to session (`references/handoff.md`), but some exits end it for good: a finish-only pass with no ticket ends its loop, a hand-off fails, or the human closes the session. Nothing starts a new chain afterwards, so slots stay free while eligible issues wait, and a PR marked Ready waits with no session to land it.

A session started by a scheduled task cannot call `create_session`, so a skill run from a scheduled task cannot start a chain. The two jobs are split instead:

- **The gate runs in GitHub Actions.** `scripts/delegate-fire` asks `delegate-status next-action` and `lease status` whether a chain is needed. It reads GitHub with the workflow's `GITHUB_TOKEN` and uses no model, so a run that does not fire costs a few seconds of Actions minutes.
- **The session starts through a scheduled task's API trigger.** When the gate passes, the script POSTs to the trigger. Each fire starts one fresh session whose prompt is `/delegate loop`. That session *is* the new chain: it takes its own slot with `lease take` and runs, or, when every slot is held, finishes the PRs that need it and ends.

## What the gate decides

Without a reserve token the script fires at most once per run:

| `next-action` | Fires when |
|---|---|
| `pick` | the lease has a free slot |
| `watch` or `land` | always. These name only a PR no session holds a claim on, and a live chain acts only on its own ticket's PR, so no running chain would reach it. On a full lease the fired session's pass is finish-only |
| `idle` | never |

It reads the same parameters `/delegate` does from the project's `.claude/delegation.md` (`label`, `rank_labels`, `branch_prefix`, `progress_label`, `max_worktrees`, `max_open_prs`, `land`, `claim_ttl` and `max_chains`), plus `weekdays_only`, and refuses to run without that file.

### Filling every free slot

With a reserve token (`--reserve`, the `reserve-token` secret below) one run starts a chain for every free slot that has work, so an emptied lease refills in one run, not one slot per run:

1. `next-action --picks <max_chains>` lists the eligible issues no chain holds, in rank order, cut to the room left under `max_open_prs`, and the PRs a chain-less session would finish.
2. For each listed issue, up to the lease's free slots, the gate names a new session with 8 random hex characters, runs `lease take` and `ticket set <n>` in that name, and fires with the hand-off line `Delegator hand-off from delegate-fire; session name <name>; ticket #<n> chain <name>.` The session starts holding its slot and its issue, as a hand-off successor does (`references/handoff.md`), so two sessions started together never race for one issue, and a run a minute later sees both as taken. When another chain took the issue first, the gate releases the slot and skips it; when the lease filled first, it stops.
3. When `finish` names PRs, it fires one more session, holding nothing, to finish them all. It runs as the one-fire `watch` or `land` fire does.

A started session whose issue was closed, unlabelled or taken by the time it ran finds its ticket complete, and Picks as usual with the slot it already holds. A reservation for a session that never starts lapses: the slot after `claim_ttl`, the ticket after `ticket_ttl`. When a fire fails, the gate releases that session's ticket and slot, goes on with the rest, and exits 1.

`max_chains` is the only cap on spend: set it to the chains you are willing to pay for at once.

### Weekdays only

With `weekdays_only` set to `on` in the Parameters table, the gate fires nothing on a Saturday or Sunday (UTC), whether a cron or an event ran it, unless forced. Chains already running carry on.

## Setup

1. **Create the scheduled task** on claude.ai, in the environment `references/cloud-environment.md` describes:
   - prompt `/delegate loop` (`/craft:delegate loop` when craft is installed as a plugin), not `/loop /delegate`: a session that something other than you started may be a relay participant, where Claude Code refuses `/loop` (**Loop command** in `references/watch.md`);
   - a fresh session on each fire;
   - the project's repository attached;
   - the GitHub connector only, because every attached connector costs context on every pass;
   - no schedule of its own: the workflow decides when it fires.
2. **Add an API trigger** to the task and copy its URL and token. The token is shown once.
3. **Add two repository secrets** in the project, for example `DELEGATOR_FIRE_URL` and `DELEGATOR_FIRE_TOKEN`.
4. **Add a reserve token**, to fill every free slot in one run: a fine-grained personal access token of the login the delegator posts as, for the project repository alone, with **Issues: read and write**, saved as a third secret such as `DELEGATOR_RESERVE_TOKEN`. Ticket markers and lease claims count only when that login posts them, which the workflow's own token cannot do. Without it a run fires at most once.
5. **Add the caller workflow** below as `.github/workflows/delegator-fire.yml`. Pin both `uses:` and `craft-ref` to the same craft release tag, so the workflow and the script it runs come from one version.
6. **Test the trigger.** Run the workflow by hand with `force` on, then check that the fired session takes a lease slot and starts a pass. Run it with `dry-run` on to see what the gate would decide without firing; a dry run needs no fire secrets, and with the reserve token it lists the issues it would start chains for.

```yaml
name: Delegator fire

on:
  schedule:
    - cron: "*/15 * * * 1-5" # every 15 minutes on weekdays, UTC
  issues:
    types: [labeled]
  pull_request:
    types: [ready_for_review, closed]
  pull_request_review:
    types: [submitted]
  workflow_dispatch:
    inputs:
      force:
        description: Fire even when the gate finds nothing to do
        type: boolean
        default: false
      dry-run:
        description: Decide and report, but never fire
        type: boolean
        default: false

permissions:
  contents: read
  issues: read
  pull-requests: read
  checks: read
  statuses: read

jobs:
  fire:
    uses: conjurer-rich/skills/.github/workflows/delegate-fire.yml@v6.0.0
    with:
      craft-ref: v6.0.0
      force: ${{ inputs.force == true }}
      dry-run: ${{ inputs.dry-run == true }}
    secrets:
      fire-url: ${{ secrets.DELEGATOR_FIRE_URL }}
      fire-token: ${{ secrets.DELEGATOR_FIRE_TOKEN }}
      reserve-token: ${{ secrets.DELEGATOR_RESERVE_TOKEN }}
```

The called workflow's job asks for the same read-only permissions, and a called workflow can never have more than its caller grants; the reserve token carries its own write access. A cron or event run has no inputs, so both flags read false.

The events wake the gate when something it waits on changes: an issue gains the label, a PR is marked Ready, is reviewed, or closes and frees a slot. The cron catches what no event announces, chiefly a slot that lapsed with a dead chain. A run that fires nothing costs a few seconds of Actions minutes, and the `concurrency` group queues runs, never overlaps them. Every run is cheap, and with a reserve token a run cannot double-fire for a slot or issue another run reserved, so the reusable workflow runs on every event by default. When the delegator has a login of its own, `skip-own-events: true` skips the events that login caused (every pass labels issues and opens or readies PRs), except a closed PR. Leave it off when the delegator posts as you, through your `gh` auth: the filter cannot tell its events from yours, and would skip your own labels, Ready clicks and reviews. A pull request from a fork gets no secrets, so the gate cannot fire on it; the next cron run catches up.

Each run writes one line to its job summary: why it did not fire (`idle`, `weekend`, or `full` when the only work is a new issue and every slot is held), or `fired` with each new session's issue and id, and any failures. Read those lines, and `delegate-status cost`, after the first day, then tune `max_chains` or the cron.

## Without the reusable workflow

The script runs anywhere with `bash`, `git`, `gh`, `jq` and `curl`, from the project's checkout:

```bash
DELEGATE_FIRE_URL=… DELEGATE_FIRE_TOKEN=… GH_TOKEN=… DELEGATE_STATUS_LOGIN=… scripts/delegate-fire --dry-run
```

Add `--reserve` when `GH_TOKEN` writes issues as the delegator's login.

`DELEGATE_STATUS_LOGIN` is the login the delegator posts as. Only markers and claims that login posted count, so the gate must know it. With a personal token it can be left unset: the token's user is the login.

It exits 0 when it fired or had nothing to do, 1 when the gate or the trigger failed, and 2 on a usage error, such as a missing secret.

## Caveats

- **The gate sees no worktrees.** A runner has no delegated worktrees, so the `max_worktrees` budget always reads empty there. `max_open_prs` (drafts awaiting a first look, **Count** in `references/work.md`) and the lease are the limits that hold.
- **Whose markers count.** The delegator trusts only markers and claims posted by its own login. A workflow token is no user, so the reusable workflow passes the caller repository's owner as that login. When the delegator posts as someone else, for example in a repository an organisation owns, set the `delegator-login` input to that login.
- **A race ends the fired chain early, without a reserve token.** The gate reads the lease a minute or so before the fired session starts, and another chain may take the last slot in between. The fired chain's `lease take` then prints `full`, and its pass is finish-only: it reviews, lands and syncs what needs it, picks nothing, and ends. The workflow's `concurrency` group stops two runs from overlapping. With a reserve token the gate takes the slot before it fires, so the race cannot happen.
- **The reserve token is a credential.** It can write every issue and comment in the repository as the delegator's login. Scope it to the one repository and to Issues alone, and give it an expiry.
- **A waiting chain's slot lapses.** In a cloud container a chain waiting on a human loses its heartbeat with the reclaimed container, and its slot lapses after `claim_ttl`. The gate then counts the slot as free and fires a chain for other work. That is intended: `max_chains` caps active chains, and `max_open_prs` caps work waiting on a first look. A chain with a slot acts only on its own ticket's PR, so the waiting PR is answered and landed by the session that owns it when its subscription wakes it, with or without a slot (**Finish-only** in `references/run.md`). When that session is gone, the gate fires one for it: `watch` and `land` name only PRs no session holds a claim on, and fire whatever the lease holds.
- **Trigger limits.** A scheduled task's API trigger accepts 30 fires per hour. A reserving run fires at most `max_chains` plus one, and reservations stop the next run from firing for the same slots, so the limit binds only when `max_chains` nears 30.
- **A private craft copy.** The reusable workflow checks out `conjurer-rich/skills` without a token. A fork kept private needs its own checkout step with a token that can read it.
- **Usage limits are not visible from GitHub.** If spend runs too high, lower `max_chains`: it caps the chains at once whatever wakes the gate.
