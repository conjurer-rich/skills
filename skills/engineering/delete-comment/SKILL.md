---
name: delete-comment
description: Use when asked to clear, delete or classify the comments in a folder, package or codebase, or to "/delete-comment <path>". Classes every comment as Tautology, Stale, Excuse or Decision Record. Tautology and Stale comments are deleted. An Excuse is deleted and filed as an issue to fix the hack. A Decision Record moves into an ADR or the reference doc that owns it. Then tightens the project's comment ratchet, or sets one up.
argument-hint: "<path> [<path>…]"
---

# /delete-comment <path> [<path>…]

Clear every comment under the given paths, keep what deserves keeping somewhere that is reviewed, and stop new comments arriving.

Comments are untested prose beside the code. They fall into four kinds, and only one of them carries information the code cannot, and that one belongs in a document, not beside one call site:

| Kind | What it is | Where it goes |
|---|---|---|
| **Tautology** | Says again what names, types or the test title already say. Section dividers, step narration, commented-out code. | Nowhere. Delete it. |
| **Stale** | Describes code, behaviour, an issue or a PR that no longer holds. | Nowhere. Delete it. |
| **Excuse** | Makes a hack acceptable: "for now", "until", "temporary", TODO, "workaround", a cast "because", a known gap. The next reader takes it as permission and copies the pattern. | Delete it and file an issue to fix the hack. |
| **Decision Record** | A real decision the code cannot show: a domain rule, an invariant, a trade-off, a rejected alternative, a contract callers rely on. | Delete it and record the decision in an ADR, or in the reference doc that already owns it. |

If no path is given, measure the candidate folders and pick the smallest whole package or feature folder that still has comments. Say which one you picked.

## 1. Measure and list

Use the project's comment scanner if it has one (look for a `comments:*` script or a comment baseline file). Otherwise list comments with the language's own parser or tokenizer, never a regex: `//` inside a string, a URL, a template literal or a regex literal is not a comment.

Never touch **tool directives**. They are read by a tool, not a person: lint suppressions (`biome-ignore`, `eslint-disable`, `noqa`, `# type: ignore`), compiler pragmas (`@ts-expect-error`, `@ts-ignore`), test-runner and mutation-tool pragmas (`@vitest-environment`, `Stryker disable`), `/// <reference>`, bundler hints (`/* @vite-ignore */`, `#__PURE__`), source-map URLs, shebangs, licence headers a tool checks, and encoding or `go:` / `#[…]` style directives.

Record a count per file before you start: files, comments, comment lines, and lines that hold nothing but a comment (the lines deletion actually removes).

For more than about 300 comments, split the work by folder and spawn parallel subagents, one per disjoint file list, each with steps 2 to 4. Workers must not commit, stash, or touch files outside their list. Without subagents, work the folders one after another.

## 2. Classify every comment

- **Check Stale against the code.** A comment that names a function, file, issue or behaviour is Stale only if that thing has changed or gone. Look.
- A mixed block takes the category of its most valuable part. Record only the decision itself.
- In a test file, a comment that says *which rule a case pins* is a Decision Record about that rule.
- A decision may already be recorded: in the ADRs, the module or reference docs, a spec. If so, name that doc and do not duplicate it.

Keep a ledger in a scratch file, one JSON line per comment: `file`, `line`, `category`, a summary of 20 words or fewer, `recordedIn`, and `issue` (`{title, body}` or null). The ledger is the evidence for the PR body and the input to step 4.

## 3. Edit

- Delete only comments. Do not change code tokens, rename anything or refactor. Making a name say what a comment said is a separate change, made test-first.
- Delete a JSX `{/* … */}` whole, including its braces.
- Remove blank lines the deletion leaves hanging, then run the project's formatter on the touched paths.
- If a tool parses the comment text, it is a directive: keep it, and add its pattern to the scanner's exemption list with a test.
- If deleting comments pushes a file past a size limit the project enforces, split the file the way that limit asks. Do not raise the limit.

## 4. Record

**ADRs.** Group the Decision Records by theme, one ADR per theme. Not one per comment, and not one for everything. Take the next free numbers and follow the format of the ADRs before them. Typically that is Status, Date, Deciders, Related (add "Recovered from code comments removed by /delete-comment."), Context, Decision (numbered rules, each naming the code it governs), Consequences, and Alternatives considered where a rejected alternative was recorded. Add each ADR to the project's ADR index. Use the project's domain vocabulary. If the project has no ADR folder, ask where decisions live before creating one.

**Issues.** Merge duplicate Excuses into one issue, and search open issues for the same hack first. Title each issue as an imperative ("Replace the cast in X with a parsed schema"). In the body, quote the deleted comment word for word, name the file and function, and describe the proper fix.

## 5. Tighten and verify

- The scanner lists nothing under the cleared paths.
- The ratchet baseline is tightened (it only ever goes down).
- Lint, build and the touched packages' tests pass.
- `git diff --stat` over the cleared paths shows deletions, plus only the splits step 3 forced.

Open a PR. Its body gives the counts per category, the lines shed, links to the new ADRs and the list of filed issues.

## No ratchet yet?

Deleting comments once does not stop them coming back. If the project has no comment ratchet, propose one in the same PR, or as the first PR if the user would rather review it apart. [references/comment-ratchet.md](references/comment-ratchet.md) describes the design: a parser-based scanner, a per-file baseline that fails on growth *and* on unrecorded shrinkage, and an update command that only tightens. Record the rule itself in an ADR.
