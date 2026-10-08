# Upstream watch

craft borrows from other skill libraries but does not merge them. Once a week a
Claude Code Routine reports what changed upstream and what craft might do
about it, as one GitHub issue labelled `upstream-watch`. Acting on an item is
an ordinary pull request.

| File | What it holds |
| --- | --- |
| [`sources.json`](sources.json) | The upstream repositories, the paths watched in each, and the revision the first review starts from |
| [`skill-map.json`](skill-map.json) | Upstream names that differ from craft's (`code-review` → `review`), and units mapped to `null` that are never relevant |
| [`ROUTINE.md`](ROUTINE.md) | The routine's instructions |
| [`../scripts/upstream-changes`](../scripts/upstream-changes) | Lists commits and changed skills since a revision; the routine's deterministic half |

Each issue ends with a marker recording the revision every source was
reviewed up to; the next run starts there, so closing or leaving an issue open
does not matter to the routine.

## Running it by hand

```sh
scripts/upstream-changes                                   # from the baselines
scripts/upstream-changes --since mattpocock/skills=<sha>   # from a revision
```

## Changing what is watched

- **Add a source:** add an entry to `sources.json` with its `baseline` set to
  the upstream's current head, so the first report is not its whole history.
- **A renamed or equivalent skill:** map it in `skill-map.json`.
- **Never relevant:** map it to `null`.

The routine itself is configured in Claude Code (Routines). Its prompt only
points here: change `ROUTINE.md`, not the Routine.
