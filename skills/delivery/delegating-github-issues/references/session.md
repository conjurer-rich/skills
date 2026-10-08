# Session title and cloud runs

**Hand-off** and the **Stop rule** procedure live in `references/handoff.md`.

## Session title

The chat's name is how the human finds one delegator session among several, in the Claude Code on the web sidebar, the `/resume` picker and the terminal title, so a session names itself after the last item it worked on. The title stays after the session releases its claim, so a finished PR can still be traced to the session that handled it, and only the next item replaces it. The title changes at these moments, and only when the new title differs from `title` in `run-state.json`:

| Moment | Title |
|---|---|
| **Work** step 2, once the claim on issue N wins | `#N <issue title>` |
| **Work** step 12, once the PR opens | `PR #P (#N) <issue title>` |
| **Review** step 1, once the claim on PR P wins | `Review PR #P <PR title>` |
| **Land** step 1, once the claim on PR P wins | `Land PR #P <PR title>` |
| **Sync** step 1, once the claim on PR P wins | `Sync PR #P <PR title>` |
| A **Watch** or **Run** pass ends and the session has held no item yet (`title` in `run-state.json` is empty) | `/delegate watching <owner>/<repo>` |
| **Hand-off** step 3, once the next session starts | `[handed off → <id>] <title>` |
| **Hand-off** ends the loop without a next session | `[loop ended] <title>` |

Cut the item's title at a word boundary with `…` so the whole stays within 60 characters. A Work, Review, Land or Sync the human started by hand keeps its item's title when it stops, and so does a run that trips the **Stop rule** or goes to **Blocked**: the title still says where the staged work is. A session that **Hand-off** ends adds a prefix to that title, so the human can pick out the stopped sessions in the sidebar: `<title>` is the current `title` in `run-state.json`, or the watching form when it is empty, and `<id>` is the last 8 characters of the new session's id, the end of its URL. The prefix is never cut; `<title>` is. Only a Watch or Run pass sets the watching form, only at its end, and only before the session's first item; once a session has worked an item it never goes back to the watching form.

Set it with one call, counted in `tool_calls`, and write the new title to `run-state.json`. A rename that fails is reported in one line of the pass report and never stops a run: the title is a convenience.

- **Claude Code on the web.** The `set_session_title` tool of the `claude-code-remote` MCP server, whenever it is in the tool list. Its `session_id` is the `ccr.id` that `get_session` returns with no arguments. Call `get_session` once per session, not once per run: write the id to `ccr-session-id` in the session's scratch directory, write its first outcome branch to `ccr-outcome-branch` (`session_context.outcomes[0].git_info.branches[0]`, empty when there is none) for **Hand-off**, and on every later pass, a `/loop` pass included, read it from there and copy it into `run-state.json` as `ccr_session_id`. That is the id the sidebar knows; `CLAUDE_CODE_SESSION_ID` is a different id and is not it.
- **The CLI.** No tool renames a session and a skill cannot run `/rename`. `/rename` itself appends a `custom-title` record to the session transcript, and Claude Code picks one up that another process appended the next time it reads the end of its transcript (after about 32 KB of its own writes, or at a compaction), so append the same record:

  ```bash
  jq -nc --arg t "<title>" --arg s "$CLAUDE_CODE_SESSION_ID" \
    '{type:"custom-title",customTitle:$t,sessionId:$s}' \
    >> ~/.claude/projects/*/"$CLAUDE_CODE_SESSION_ID".jsonl
  ```

  `CLAUDE_CODE_SESSION_ID` is set in every Claude Code session and exactly one transcript carries that name, so the glob expands to the one file. The redirect fails with `ambiguous redirect` when it does not; report that and carry on.

## Running in a cloud container

Advice to the human, not instructions to the delegator:

- Run `/delegate` in a dedicated environment with only the GitHub connector attached; every attached MCP server's tool list is loaded on every turn.
- The container is reclaimed once the session sits idle, and an in-container wakeup timer such as `ScheduleWakeup` is lost with it, silently: the loop then waits for a PR event or a message from you. That is why the loop schedules its next pass with `send_later`, a reminder kept on the server that starts the session again in a new container. A pending reminder shows in your Routines list as `delegate next pass`.
- Do not run it with the `learning` output style or any output style that adds per-turn commentary.
- A worktree carries a second copy of the project's `CLAUDE.md`. With the delegator staying in the main checkout, that copy no longer loads into the delegator's context on every turn, which is one more reason the delegator never enters a worktree.
- A global stop hook that nags to commit and push (the dotfiles `stop-hook-git-check.sh`) fires on every delegator stop while staged work is intentionally uncommitted. That hook stays silent when the worktree holds a `.delegator/` marker directory or `DELEGATOR_RUN=1` is set; **Work** step 5 creates the marker.
