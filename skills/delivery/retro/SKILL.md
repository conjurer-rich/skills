---
name: retro
description: Run a retrospective on a coding session and propose changes to the agent's environment, not the code — navigation pointers, automated checks, coding standards, steering files, tooling, information access, and craft skills the session should have used but did not. User-invoked; run it in the session it reviews, before clearing.
disable-model-invocation: true
---

# Retro

You are reviewing a coding session to make the **next** session go better. The
output is a ranked list of proposed changes to the environment the agent works
in. Do not change code, and do not apply any proposal until the user picks it.

## Steps

1. **Load the writing guide.** Load `writing-for-agents`: most
   proposals change a file an agent reads, and it says how those should be
   written.
2. **Read the primary sources.** Default to the current session. If the user
   names another session, read its log rather than relying on memory. For a
   long session, spawn subagents to read different stretches of the log in
   parallel and report back; read it yourself, start to end, where the harness
   has no subagents.
   - Claude Code: session logs are the `.jsonl` files under
     `~/.claude/projects/<project>/`. Codex and other harnesses keep their own
     session history; use whatever the harness provides.
3. **Look for candidates** in each category below. A category with nothing to
   report is skipped, not padded.
4. **Present the candidates, most severe first.** For each: what happened
   (quote or cite the moment in the session), the proposed change, and where it
   should live. Use `expectations` to choose the owner when it is not obvious.

## Categories

- **Navigation.** How quickly did the agent find the right files? Are there
  hidden dependencies between files? Would a **navigation pointer** help?
  *Use when* the session spent a long time finding something.
- **Automated checks.** Could a lint rule, type check, test or filesystem check
  have caught a mistake the agent made? Read the repository's own check
  commands first (its `package.json` or build-tool scripts, its CI workflow):
  a check that exists but is not wired up, or is silently broken, is the
  finding, not a reason to write a new one. A repository with no guardrail at
  all (no pre-commit hook and no CI job running its checks) is itself a
  finding. *Use when* the agent made a mistake a check could have caught.
- **Coding standards.** Should the reviewer enforce a new rule, or should an
  existing rule be clarified or removed? Classify the violation first. A
  **mechanical** one (a fixed syntactic pattern, a banned API, an import shape,
  a file-location rule) gets a deterministic check, in the repository's own
  linter, a hook or a CI job, whichever is cheapest. Default to building the
  check over writing the rule. Keep written standards for genuine **judgement
  calls**. *Use when* review failed to catch a mistake.
- **Steering files.** Should anything in `CLAUDE.md` / `AGENTS.md` (the
  repository's or the global one) move to a written standard, a check, or a
  skill? *Use when* those files are long. Also look for **no-ops**: lines that
  change nothing about what the agent does.
- **Tool economy.** Did the agent make expensive or repetitive tool calls that
  a better command, script or tool would shorten? *Use when* the session spent
  heavily on one kind of call.
- **Information access.** Was something the agent needed out of reach — server
  logs, a read-only view of a third-party service, a running app? *Use when* a
  crucial piece of information was missing.
- **Missed skills.** Did the session do by hand something a craft skill
  covers? Compare what happened against the map in
  [`../ask/SKILL.md`](../ask/SKILL.md): a shipped skill that was never loaded,
  a shelved skill worth promoting, or a recurring kind of work with no skill
  at all (a candidate for `find-skills`). Name the moment it would have
  helped. *Use when* the session improvised a process, or `engineering-practice`
  would have routed the work elsewhere.

## Reference

### Implementation and review

Work passes through two stages. The implementing agent carries the most
context pressure: it explores, writes code and debugs. The reviewing agent
receives a diff and needs no exploration. So the reviewer, not the
implementer, should carry the coding standards.

### Where changes live

- **`CLAUDE.md` / `AGENTS.md`** is loaded into every session in that scope.
  Use it sparingly, mostly for navigation pointers.
- **Coding standards** are read at review time, not during implementation.
- **Docs** are reference material that other files point to. Look for an
  existing doc before writing a new one.
- **Skills** are for procedures and knowledge loaded on demand (only their
  description is always loaded), and for user-invoked commands.
