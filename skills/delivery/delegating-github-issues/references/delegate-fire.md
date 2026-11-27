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

Before a `watch` or `land` fire, the gate re-reads the live claim on each PR it would finish with `delegate-status holder <n>`, the rule `claim` decides by, and leaves out the claimed ones. A Ready click both starts the workflow and wakes the PR's own subscribed session, which claims the PR to land it, so the first read can be stale by the time the gate fires. With every such PR claimed it fires nothing and reports `claimed (PR #N by <session>)`, unless a pick has a free slot, when it fires for the pick instead. A session started for a PR another session holds could only see the claim and stop.

It reads the same parameters `/delegate` does from the project's `.claude/delegation.md` (`label`, `rank_labels`, `branch_prefix`, `progress_label`, `max_worktrees`, `max_open_prs`, `land`, `claim_ttl`, `max_chains`, `assignee_routing`, `answer_review_requests` and `rereview`), plus `weekdays_only` and, for a team, `roster`, `max_chains_per_login` and `rereview_command` (**Team setup** below), and refuses to run without that file.

### Filling every free slot

With a reserve token (`--reserve`, the `reserve-token` secret below) one run starts a chain for every free slot that has work, so an emptied lease refills in one run, not one slot per run:

1. `next-action --picks <max_chains>` lists the eligible issues no chain holds, in rank order, cut to the room left under `max_open_prs`, and the PRs a chain-less session would finish.
2. For each listed issue, up to the lease's free slots, the gate names a new session with 8 random hex characters, runs `lease take` and `ticket set <n>` in that name, and fires with the hand-off line `Delegator hand-off from delegate-fire; session name <name>; ticket #<n> chain <name>.` The session starts holding its slot and its issue, as a hand-off successor does (`references/handoff.md`), so two sessions started together never race for one issue, and a run a minute later sees both as taken. When another chain took the issue first, the gate releases the slot and skips it; when the lease filled first, it stops.
3. When `finish` names PRs, it re-reads their claims as the one fire does, then fires one more session, holding nothing, to finish those no session has claimed. It runs as the one-fire `watch` or `land` fire does.

A started session whose issue was closed, unlabelled or taken by the time it ran finds its ticket complete, and Picks as usual with the slot it already holds. A reservation for a session that never starts lapses after `claim_ttl`, the slot and the ticket alike: a ticket marker keeps its 12-hour `ticket_ttl` only once a session has claimed the issue under it. When a fire fails, the gate releases that session's ticket and slot, goes on with the rest, and exits 1.

An issue whose chain was waiting on you is picked the same way once you answer. A 👍 on its derived criteria, or a reply to its question, lapses the old chain's ticket (**Ticket** in `references/run.md`), the issue reads `free`, and the next run reserves it for a new chain. Neither a reaction nor a comment fires the workflow, so the next cron run is the one that notices.

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
4. **Add a reserve token**, to fill every free slot in one run: a fine-grained personal access token of the login the delegator posts as, for the project repository alone, with **Issues: read and write** and **Pull requests: read-only** (setting a ticket reads the open PRs), saved as a third secret such as `DELEGATOR_RESERVE_TOKEN`. Ticket markers and lease claims count only when that login posts them, which the workflow's own token cannot do. Only the reservations use it; the gate's reads keep the workflow token. Without it a run fires at most once.
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

The called workflow's job declares no permissions of its own, so it runs with exactly what the caller grants, and a called workflow can never have more; the reserve token carries its own write access. A team caller grants `issues: write` too (**Team setup**). A cron or event run has no inputs, so both flags read false.

The events wake the gate when something it waits on changes: an issue gains the label, a PR is marked Ready, is reviewed, or closes and frees a slot. The cron catches what no event announces, chiefly a slot that lapsed with a dead chain. A run that fires nothing costs a few seconds of Actions minutes, and the `concurrency` group queues runs, never overlaps them. Every run is cheap, and with a reserve token a run cannot double-fire for a slot or issue another run reserved, so the reusable workflow runs on every event by default. When the delegator has a login of its own, `skip-own-events: true` skips the events that login caused (every pass labels issues and opens or readies PRs), except a closed PR. Leave it off when the delegator posts as you, through your `gh` auth: the filter cannot tell its events from yours, and would skip your own labels, Ready clicks and reviews. A pull request from a fork gets no secrets, so the gate cannot fire on it; the next cron run catches up.

Each run writes one line to its job summary: why it did not fire (`idle`, `weekend`, or `full` when the only work is a new issue and every slot is held), or `fired` with each new session's issue and id, and any failures. Read those lines, and `delegate-status cost`, after the first day, then tune `max_chains` or the cron.

## Team setup

Without a `roster` the gate assumes one delegator login and one trigger. A team in which each teammate runs the delegator as themselves, through their own `gh` login and their own scheduled task, needs one more rule: **one GitHub event wakes exactly one teammate's trigger, never two.** Claims and lease slots already exclude sessions across logins, so a second session would do no harm, but it would spend tokens only to find the first one's claim and stop. Ticket markers and the criteria 👍 count only for the login that posted them, so a reservation made for one teammate does not stop another teammate's session either. The roster routes each event to its owner instead, and the issue's assignee records who that is.

### How events are routed

Every rule fires at most one teammate's trigger. Each teammate's gate runs as that login (`DELEGATE_STATUS_LOGIN`) with `--assignee-routing strict`: it sees only issues assigned to that login alone, and only delegated PRs that login opened.

| Event | Routes to |
|---|---|
| `issues` `labeled`, with the `label` parameter (any other label, the delegator's own `progress_label` included, is ignored) | The issue's one human assignee. With none, the event's sender: the gate assigns them, then fires. Several assignees, or an owner not on the roster, fire nothing, and the summary says why. |
| `pull_request` `ready_for_review` or `closed`, and `pull_request_review` `submitted` | The PR's author, when its branch starts with `branch_prefix`. The `delegate-status holder` re-check still runs before a watch or land fire. |
| `schedule` and `workflow_dispatch` | Each roster login in turn. First, each labelled issue with no human assignee and no delegated PR goes to the actor of its latest `labeled` event in the issue timeline, when that actor is on the roster, and is assigned to them before any gate runs. Any other is skipped and reported. |

**Assigning is the lock between logins.** The assignment is made with the workflow token, and the workflow's `concurrency` group runs one gate at a time, so two runs can never assign one issue to two people. That is why a team's caller grants `issues: write`. A teammate's own session keeps the lock too: with `assignee_routing` on, its `claim` assigns its login, re-reads the assignees first and backs off when someone else was assigned, and only a `--delete` release undoes an assignment its claim made (**Claims** in `SKILL.md`). Set `assignee_routing` to `on` (or `strict`) in the Parameters table so the sessions follow the same rule as the gate.

An assignment made with the workflow's `GITHUB_TOKEN` starts no new workflow run: GitHub does not start workflows for events that token causes, other than `workflow_dispatch` and `repository_dispatch`. The caller below does not listen for `assigned` events either, so the gate's own assignments never wake it again.

The timeline read that finds an issue's labeller (`GET /repos/{owner}/{repo}/issues/{n}/timeline`, whose `labeled` events carry `actor` and `label`) needs only `issues: read`, which the caller grants already. `delegate-status` already reads PR timelines with the same token.

**Slots.** `max_chains` stays one pool for the whole team: claims and slots work across logins. Each login's gate sees the free slots left after the logins gated before it in the same run, counting a fire this run made without reserving as a slot taken. With `max_chains_per_login` set, the gate counts live lease slots by their comment's author and fires no pick for a login already at that many (`cap`); a login at its cap still gets a watch or land fire, since the lease caps new work, never finishing.

**Reserving.** A login reserves its slots and issues, as `--reserve` does, only when its entry in the triggers secret has a `reserve_token`, a token of that login (scoped as in step 4 of **Setup**). Without one, that login gets at most one fire per run. The workflow's `reserve-token` secret is not used with a roster.

### Setting it up

1. **One scheduled task and API trigger per teammate**, each created by that teammate on their own claude.ai account, as steps 1 and 2 of **Setup** describe. Each fired session runs `/delegate loop` as its owner, through that owner's GitHub connector.
2. **One repository secret**, for example `DELEGATOR_TRIGGERS`, holding one JSON object that maps each login to its trigger, and optionally its reserve token:

   ```json
   {
     "alice": {"url": "https://api.anthropic.com/v1/…/fire", "token": "…", "reserve_token": "github_pat_…"},
     "bob": {"url": "https://api.anthropic.com/v1/…/fire", "token": "…"}
   }
   ```

   One secret means the reusable workflow takes one secret input and never builds secret names at run time. A roster login with no entry is reported as `no trigger` and never fired, nor assigned an issue.
3. **The roster and routing** in `.claude/delegation.md`:

   ```markdown
   | `roster` | `alice`, `bob` |
   | `assignee_routing` | on |
   | `max_chains` | 4 |
   | `max_chains_per_login` | 2 |
   ```

4. **The caller workflow**, as below. It differs from the single-login one in its `issues: write` permission and the `triggers` secret.

```yaml
name: Delegator fire

on:
  schedule:
    - cron: "*/15 * * * 1-5"
  issues:
    types: [labeled]
  pull_request:
    types: [ready_for_review, closed]
  pull_request_review:
    types: [submitted]
  workflow_dispatch:
    inputs:
      dry-run:
        description: Decide and report, but never assign or fire
        type: boolean
        default: false

permissions:
  contents: read
  issues: write # the gate assigns each issue to its owner: the lock between logins
  pull-requests: read
  checks: read
  statuses: read

jobs:
  fire:
    uses: conjurer-rich/skills/.github/workflows/delegate-fire.yml@v6.4.0
    with:
      craft-ref: v6.4.0
      dry-run: ${{ inputs.dry-run == true }}
    secrets:
      triggers: ${{ secrets.DELEGATOR_TRIGGERS }}
```

The routing inputs (the event's name and action, the issue or PR number, the label, the sender, the PR's author and branch) come from the event context inside the reusable workflow, never from the caller. Leave `skip-own-events` off: every teammate's label and Ready click is an event of a login on the roster. Run it by hand with `dry-run` on first: the summary shows whom each issue would be assigned to and what each login's gate would do, and nothing is assigned or fired.

Each run writes one line per routing decision (`#12: assigned to bob (labelled by bob)`, `#13: skipped (labelled by carol, who is not on the roster)`, `#9: ambiguous assignees (alice, bob)`) and one per login whose gate ran: `fired` with its issue or PR and session, or why not (`idle`, `full`, `cap`, `claimed`, `no trigger`).

### Re-reviews after fixes

With `rereview` on in `.claude/delegation.md`, a teammate whose `review-requests` review opened threads on a delegated PR gets a re-review once the delegator has answered them, without starting it by hand:

1. **Review** step 6 (`references/review.md`) re-requests that teammate's review after answering one of those threads with a fix, when a `blocking` or `should fix` one is still unresolved. The PR re-enters their `review-requests` queue, which their own `/loop /review-requests` picks up. That alone works with or without a roster or this workflow.
2. With a roster, the request's `pull_request` `review_requested` event can also wake that teammate's review task at once. Each teammate who wants this creates a second scheduled task, as steps 1 and 2 of **Setup** describe but with the prompt `Re-review the pull request the next message names, with the review-requests skill.`, and adds its trigger to their entry in the triggers secret:

   ```json
   {
     "bob": {"url": "…", "token": "…", "review_url": "https://api.anthropic.com/v1/…/fire", "review_token": "…"}
   }
   ```

   The fire's text is `<rereview_command> <owner>/<repo>#<n>`, with `rereview_command` defaulting to `/review-requests` (set it to `/craft:review-requests` when craft is installed as a plugin). Add `review_requested` to the caller's `pull_request` types:

   ```yaml
     pull_request:
       types: [ready_for_review, closed, review_requested]
   ```

The gate fires the reviewer's `review_url` only when the PR is delegated, the requested reviewer is on the roster, is not the PR's author and has a `review_url`, their latest submitted `review-requests` review on it was of an older head, and a `blocking` or `should fix` thread that review opened is still unresolved (`delegate-status rereview <n>`). Any other request, a teammate asking for a first review included, is reported and fires nothing; a reviewer without a `review_url` is reported as `no review trigger` and their own loop picks the request up. A teammate with a `review_url` need not also run `/loop /review-requests` for these PRs.

**The exchange ends.** The re-review resolves the threads it confirms fixed only with `resolve_fixed_threads` on and `post: comment` in their `.claude/review-requests.md`; under `post: pending` they resolve them when they submit. A re-review that leaves no `blocking` or `should fix` thread open makes nothing re-request them. Its submitted body needs no answer unless it lists such a finding under `## Not placed on a line`, so neither side wakes the other again. A re-review that raises a new `blocking` or `should fix` finding starts one more round, as a human reviewer's would: the delegator answers `review-requests` findings although they carry the Claude Code footer (`references/review.md` step 3), with `consider` findings too when `answer_review_requests` is `all`.

`rereview` and `answer_review_requests` are the delegator's own parameters, set in the Parameters table like the others; `references/review.md` steps 3 and 6 say what they do.

The line for this route reads `bob: fired a re-review of PR #21 (2 open threads)`, or why not (`nothing to re-review`, `already reviewed at <sha>`, `not a re-review`, `no review trigger`).

## Without the reusable workflow

The script runs anywhere with `bash`, `git`, `gh`, `jq` and `curl`, from the project's checkout:

```bash
DELEGATE_FIRE_URL=… DELEGATE_FIRE_TOKEN=… GH_TOKEN=… DELEGATE_STATUS_LOGIN=… scripts/delegate-fire --dry-run
```

Add `--reserve`, with `DELEGATE_FIRE_RESERVE_TOKEN` set to a token that writes issues as the delegator's login; unset, `GH_TOKEN` must do both. With a roster, set `DELEGATE_FIRE_TRIGGERS` instead of the URL and token, give `GH_TOKEN` issues write access, and pass the event with `--event <name> --action <a> --number <n>` plus `--label` and `--sender` (an issue event) or `--author` and `--head` (a PR event); with no `--event` it gates every login, as a cron run does.

`DELEGATE_STATUS_LOGIN` is the login the delegator posts as. Only markers and claims that login posted count, so the gate must know it. With a personal token it can be left unset: the token's user is the login.

It exits 0 when it fired or had nothing to do, 1 when the gate or the trigger failed, and 2 on a usage error, such as a missing secret.

## Caveats

- **The gate sees no worktrees.** A runner has no delegated worktrees, so the `max_worktrees` budget always reads empty there. `max_open_prs` (drafts awaiting a first look, **Count** in `references/work.md`) and the lease are the limits that hold.
- **Whose markers count.** The delegator trusts only markers and claims posted by its own login. A workflow token is no user, so the reusable workflow passes the caller repository's owner as that login. When the delegator posts as someone else, for example in a repository an organisation owns, set the `delegator-login` input to that login.
- **A race ends the fired chain early, without a reserve token.** The gate reads the lease a minute or so before the fired session starts, and another chain may take the last slot in between. The fired chain's `lease take` then prints `full`, and its pass is finish-only: it reviews, lands and syncs what needs it, picks nothing, and ends. The workflow's `concurrency` group stops two runs from overlapping. With a reserve token the gate takes the slot before it fires, so the race cannot happen.
- **The reserve token is a credential.** It can write every issue and comment in the repository as the delegator's login. Scope it to the one repository, to Issues and read-only Pull requests, and give it an expiry.
- **A waiting chain's slot lapses.** In a cloud container a chain waiting on a human loses its heartbeat with the reclaimed container, and its slot lapses after `claim_ttl`. The gate then counts the slot as free and fires a chain for other work. That is intended: `max_chains` caps active chains, and `max_open_prs` caps work waiting on a first look. A chain with a slot acts only on its own ticket's PR, so the waiting PR is answered and landed by the session that owns it when its subscription wakes it, with or without a slot (**Finish-only** in `references/run.md`). When that session is gone, the gate fires one for it: `watch` and `land` name only PRs no session holds a claim on, and fire whatever the lease holds.
- **Trigger limits.** A scheduled task's API trigger accepts 30 fires per hour. A reserving run fires at most `max_chains` plus one, and reservations stop the next run from firing for the same slots, so the limit binds only when `max_chains` nears 30.
- **A private craft copy.** The reusable workflow checks out `conjurer-rich/skills` without a token. A fork kept private needs its own checkout step with a token that can read it.
- **Usage limits are not visible from GitHub.** If spend runs too high, lower `max_chains`: it caps the chains at once whatever wakes the gate.
