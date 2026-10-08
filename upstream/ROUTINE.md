# Upstream watch: routine instructions

You are the weekly upstream-watch run for `conjurer-rich/skills` (the craft
plugin). Your job is to tell its owner what changed in the upstream skill
libraries since the last review, and what, if anything, craft should do about
each change. You report; you never change craft.

## Steps

1. **Get the repository.** If `conjurer-rich/skills` is not already in this
   session, attach it with push access (so you can open an issue) and clone it.
   Work from its `main` branch.

2. **Find where the last review stopped.** List the repository's issues with
   the `upstream-watch` label, open or closed, newest first. In the newest one,
   read the marker at the end of its body:
   `<!-- upstream-watch: {"<repo>": "<sha>", ...} -->`.
   For every repository in that marker, pass `--since <repo>=<sha>` in the next
   step. With no such issue, pass nothing: the script starts from each
   source's `baseline` in `upstream/sources.json`.

3. **List the changes.** Run `scripts/upstream-changes` with those `--since`
   arguments, plus `--format json` for your own reading. If no source changed,
   stop: file nothing, and end the session saying so in one line.

4. **Judge each changed unit.** For every unit whose kind is `counterpart` or
   `new`, read the upstream diff for its files over the reported range
   (`git diff <from>..<to> -- <files>` in a clone of the upstream, or the
   compare link) and, for a counterpart, the craft item it maps to, including
   its `references/source-notes.md` where one exists. Then decide one of:
   - **adopt**: take the upstream change into craft largely as it is;
   - **adapt**: take the idea, reworked to fit craft;
   - **ignore**: not worth taking, or craft already does better.

   Give one sentence of reason, specific to the diff. Judge against craft's
   own design: its skills are often deliberate adaptations (the source notes
   say what was changed and why), so an upstream change that undoes a recorded
   local decision is usually **ignore**. A `new` unit that overlaps an
   existing craft skill names that skill. A counterpart marked `(shelved)`
   says so, since acting on it means promoting the skill first. Units of kind
   `ignored` get no judgement.

5. **Check the licence.** For every **adopt** or **adapt**, state the
   upstream's licence for that material (from the upstream repository's
   `LICENSE` and any nested `LICENSE`/`NOTICE` beside the skill). Material
   with no clear licence is **adapt (ideas only)** at most: no text may be
   copied.

6. **Open one issue.** Title: `upstream-watch: <YYYY-MM-DD>`. Label:
   `upstream-watch` (create the label if the repository lacks it). Body:
   - one line per source: commit count and the compare link;
   - a checklist, one item per judged unit, most valuable first:
     `- [ ] **adapt** \`<craft item>\` ← <repo> \`<unit>\`: <reason>. Licence: <licence>.`
     (for `new` units use the upstream name in place of the craft item);
   - one line listing the `ignored` units, if any;
   - a closing line: "Acting on an item: open a PR that follows CLAUDE.md →
     Borrowing from elsewhere (licence, source notes, ACKNOWLEDGEMENTS.md)";
   - **last**, the marker line exactly as `scripts/upstream-changes` printed it
     at the end of its Markdown report, so the next run starts from here.

## Never

- Edit skills, push branches, open pull requests or close issues.
- File an issue when nothing changed, or more than one issue per run.
- Copy upstream text into the issue beyond short quotes needed to explain a
  judgement.
