# Harness capabilities

The references are written for Claude Code, which has every capability below.
In another harness (Codex, OpenCode), or under the `delegate-loop` runner, use
the harness's equivalent, or follow the fallback. A missing capability never
stops a run. All state lives on GitHub and in git, so nothing is lost when a
step is skipped.

## Subagents

A **dispatch** starts a subagent with a fresh context and a self-contained
brief, under the **Hand-back contract**.

- **Claude Code:** the Agent tool, with `subagent_type: general-purpose`, the
  step's `model`, and `run_in_background` as the step says. `SendMessage`
  continues a running subagent; a background task's exit wakes the session.
- **Codex:** spawn a subagent, if the harness has them.
- **Fallback:** where the harness has no subagents, start one headless process
  per brief from the main checkout (`codex exec "<brief>"` or
  `claude -p "<brief>"`), or else carry out the brief yourself. Either way, the
  brief writes its report file and you read back only the verdict.
  - "Send the implementer one message" becomes a fresh dispatch with the same
    brief, plus the findings and the earlier report's path.
  - "Run in the background" becomes running in the foreground and reading the
    result when it returns.

## Models

A step names a role, and the parameters below map each role to a model:

| Role | Parameter | Default |
| --- | --- | --- |
| Implementer, expected tier S | `implementer_model_small` | `sonnet` |
| Implementer, otherwise | `implementer_model_large` | `opus` |
| Land's review and Sync's resolution check | `review_model` | `opus` |
| Mechanical steps: bootstrap, evidence, ship, cleanup | `mechanical_model` | `haiku` |

The defaults are Claude Code model aliases. In another harness, set each
parameter to that harness's model names. Where a dispatch cannot choose its
model, ignore the parameter.

## Reviewers

- **`correctness_review`:** the bug-finding review a subagent runs on a diff.
  - Default in Claude Code: `/code-review` at medium effort.
  - Default in Codex: `codex review`.
  - `none` skips it. The **Whole diff** check then loads the `review` skill
    alone, and the PR body says so.
- **`simplify`:** Land's behaviour-preserving clean-up pass.
  - Default in Claude Code: `/simplify`.
  - Elsewhere: a subagent that loads the `refactor-scan` skill and applies only
    the refactors it recommends.

A project sets either one in its **Parameters** table.

## Scheduling the next pass

Watch step 6, the Idle pass and Hand-off schedule the next pass.

- **Claude Code:** `send_later` on the web, `ScheduleWakeup` on the CLI.
- **Elsewhere, or under `delegate-loop`:** skip it. The runner or the human
  starts the next pass.

## PR subscriptions and the background poll

- **Claude Code on the web:** `subscribe_pr_activity` wakes the session on
  GitHub events.
- **Elsewhere:** skip both the subscription and the poll. The next pass reads
  GitHub afresh.

## Session title and Hand-off

- **Claude Code:** `set_session_title` names the session. Hand-off moves the
  command to a new session with `create_session` on the web.
- **Elsewhere:** skip the title. When the **Stop rule** trips, leave the
  `<!-- delegator:handoff -->` comment, report, and end the run. Under
  `delegate-loop`, the runner's next pass starts with an empty context.
