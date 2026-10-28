---
"@conjurer-rich/skills": major
---

Remove `/delegate-spawn` and add `delegate-fire`. A session started by a scheduled task cannot call `create_session`, so `/delegate-spawn` could never start a chain from the host it was built for. `delegating-github-issues` now ships `scripts/delegate-fire` and a reusable GitHub Actions workflow, `.github/workflows/delegate-fire.yml`: on a cron it runs `next-action` and `lease status` with no model and, only while there is work and a free lease slot, fires a scheduled task's API trigger whose prompt is `/loop /delegate`. `references/delegate-fire.md` sets it up. A project that ran `/delegate-spawn` from a scheduled task should switch that task's prompt to `/loop /delegate`, give it an API trigger and call the workflow; the `spawn_per_fire` setting is no longer read.
