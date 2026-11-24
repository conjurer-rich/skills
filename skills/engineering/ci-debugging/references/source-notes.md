# ci-debugging: source notes

## Is It Still Happening?

The section comes from rule 5a, "cross-check blame against what's red right
now", in the standing rules of Anthropic's oncall-kit plugin. Its triage
skill applies the rule before naming a change as an incident's live cause:

- Repository: <https://github.com/anthropics/oncall-kit> (fork:
  <https://github.com/conjurer-rich/oncall-kit>)
- Revision: [`c03282cd`](https://github.com/anthropics/oncall-kit/blob/c03282cd5381a5a2e12e32bfb3c8957d52ce01f1/CLAUDE.md)
  (Apache-2.0), `CLAUDE.md`, rule 5a

craft narrows the rule from any monitoring signal to CI runs. An absence
counts only from a completed run of the failing job on the same branch. A run
that is in progress, was cancelled, or never reached the failing step tells
you nothing.

Licence status: ideas only, no text copied. The wording is original to this
repository.
