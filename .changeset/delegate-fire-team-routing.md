---
"@conjurer-rich/skills": minor
---

`delegate-fire` can route for a team in which each teammate runs the delegator under their own login with their own scheduled task. Set a `roster` in `.claude/delegation.md` and pass one `triggers` secret mapping each login to `{url, token, reserve_token?}`. Each event then wakes exactly one teammate's trigger:
- a label event goes to the issue's one assignee, or assigns the sender first;
- a delegated PR's Ready, close or review goes to its author;
- a cron run gates each login as itself, after assigning each unassigned labelled issue to whoever labelled it.

Assigning is the lock between logins. The new `max_chains_per_login` caps the slots one login may hold.

The new `assignee_routing` parameter (`off` by default; `on` or `strict`) teaches `delegate-status` the same rule:
- an issue assigned to another human reads `assigned` and is never picked, and `next-action` lists it under `skipped`;
- a won claim assigns the delegator's login;
- a `--delete` release unassigns the login only when that claim made the assignment.

New read and write commands back this: `assignees`, `assign` and `unassigned`. Without a roster, and with routing off, every output is unchanged.

The reusable workflow takes the routing fields from the event context and gains the `triggers` secret. Its job no longer declares its own permissions: it runs with the caller's, so a team caller must grant `issues: write`. A single-login caller with `fire-url` and `fire-token` works as before.
