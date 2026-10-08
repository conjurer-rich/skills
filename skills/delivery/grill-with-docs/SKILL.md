---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design that records the language and decisions it settles in the repository as it goes. User-invoked.
disable-model-invocation: true
---

Load the `grilling` skill and run it. As the interview settles things, record
them where the repository keeps them, in the same session:

- **Terms.** When an answer names a domain concept, coins a word, or resolves
  two words for one thing, load `ubiquitous-language` and follow its protocol
  (detect, propose, decide, record) against the repository's declared
  glossary.
- **Hard-to-reverse decisions.** When an answer settles something that would
  be expensive to undo, record it through the repository's decision mechanism:
  the `adr` agent in Claude Code, or an ADR in the repository's decision
  folder elsewhere. Routine choices need no record.

Write each record once the user has confirmed the answer, never on your own
recommendation alone. The session ends when the grilling frontier is empty
and every settled term and decision is recorded.
