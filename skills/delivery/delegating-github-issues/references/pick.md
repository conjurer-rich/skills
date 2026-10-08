# Pick

1. Run `delegate-status status --cache <scratch>/pick-cache.json`. Its `issues` are every open `<label>` issue in the skill's order: issues with the first rank label, then the second, then unranked; oldest `createdAt` first within each group. Each carries a `state`, `counts` tallies them by state, and `pick` names the issue step 2 takes (`{number, title}`, or `null`):
   - `delegated`: an open PR from a `<branch_prefix><n>-` branch exists (`pr`). Skip an issue that has an open PR from a `<branch_prefix><n>-` branch: it is already delegated.
   - `claimed`: another session holds a live claim on it (`holder`): skip an issue another session holds a live claim on.
   - `waiting-on-human`: a delegator question or derived criteria wait on the human, as **Work** step 3 defines it (`reason`). Skip it.
   - `held`: this session holds the claim; it carries `criteria` or a waiting `reason` like any other.
   - `free`, with `criteria` `body`, `confirmed` or `none`.

   An issue marked `stale_label` carries `<progress_label>` but has no live claim, so it is free: remove the label as **Stale label** in **Claims** says, and keep it as a candidate.

   **Skip cache.** `--cache` keeps `pick-cache.json` in the run's scratch directory with, per skipped issue (`claimed` or `waiting-on-human`), its `updatedAt` and `checkedAt`. The script re-reads a cached issue's comments **only** when its `updatedAt` is later than the cached value, or it was `claimed` and `claim_ttl` has passed since `checkedAt`; a skip it reuses carries `cached: true`. The aborted run re-read every skipped issue's body and comments on every loop pass when nothing on them had changed.
2. Take the first issue that is not waiting on the human and that no other session has taken, as `pick` names it: the first `free` one, or a `held` one with `criteria` (not a waiting `reason`). Read `pick` as it is printed; never re-derive it with your own `jq` filter over the status, because a filter on a key the output does not have yields nothing and reads as "no issue to pick". Continue at **Work** with it. If Work then loses the claim race for it, come back here and continue with the next `free` issue after it in `issues`.
3. If `pick` is `null`, say so, quoting `counts` (the number of issues in each state) and naming the claimed ones, and stop. A report of nothing to pick whose `counts` has a `free` entry is wrong: re-read `pick` before sending it. Do not widen the search. A cached skip is reported once per run with its reason, on the pass that first skips it, not re-explained on every pass.
