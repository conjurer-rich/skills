# A comment ratchet

A ban that has to be met in one change never lands: every comment needs a judgement, and a codebase can hold tens of thousands. A ratchet bans new comments today and lets the old ones go a section at a time.

## Pieces

**Scanner.** Walk the tracked source files (`git ls-files`) and parse each with the language's own parser or tokenizer. For TypeScript and JavaScript, `ts.createScanner` with comments kept, or the leading and trailing comment ranges of each token, handles strings, template literals, regex literals and JSX correctly. A regex does not.

For each comment, report the file, start and end line, and its text. Skip:

- generated files, build output, vendored code and visual prototypes;
- tool directives (see the list in [`../SKILL.md`](../SKILL.md)), kept in one named list with a test per entry, so adding one is deliberate.

Count **comment lines** per file: every line a comment touches. That is what the baseline stores. Separately, count lines that hold nothing but a comment, which is what deletion removes. Use it for estimates.

**Baseline.** A checked-in JSON object, one line per file: `{ "path/to/file.ts": 12 }`. Seed it from the current tree. A file absent from the baseline is allowed zero. Keep it sorted and mark it generated (for example `-diff`, or an opt-out from any file-size budget) in `.gitattributes`.

**Check** (runs inside the project's lint command, so CI and pre-push both run it):

- A file with **more** comment lines than its baseline fails. A new file has a baseline of zero.
- A file with **fewer** comment lines than its baseline also fails, with a message to run the update command. This locks every gain in. Without it the slack is quietly spent by the next change to that file.

**Update** recounts and writes the baseline, but only tightens: it lowers counts, drops files that reached zero or were deleted, and never raises a count or adds a file. Raising one is a hand edit to the baseline, visible in review.

**Estimate and list** commands take a path, for choosing the next section and for the `/delete-comment` worklist.

## Tests

Pin these with unit tests on pure functions (scan, count, compare, tighten), not on the file system:

- line, block and trailing comments, with their lines;
- comment-like text inside strings, templates and regexes is not found;
- a comment inside a JSX expression is found;
- each directive is exempt, and a shebang is not a comment;
- a comment counts every line it touches, and only comment-only lines are removable;
- compare flags growth (including a file absent from the baseline) and shrinkage (including a deleted file);
- tighten lowers, drops, and never raises or adds.

## Rule

Record the ban itself in an ADR: what counts as a comment, the directive exemptions, where each kind of comment goes instead, and that the ratchet only tightens. Say in the project's agent instructions that `pnpm lint` (or equivalent) fails when a file gains a comment, and that a PR which deletes comments runs the update command.

## Alternatives

- **A linter rule.** Check first. Most linters have no rule that bans all comments, and few express a per-file ratchet. If one does both, use it.
- **Allowing doc comments on public exports.** Usually rejected: a contract callers rely on belongs in the module's reference doc and a test, and a doc comment drifts like any other.
