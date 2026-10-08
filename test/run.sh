#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/layout-and-licensing.sh"
"$SCRIPT_DIR/skills-frontmatter.sh"
"$SCRIPT_DIR/plugin-version-sync.sh"
"$SCRIPT_DIR/skill-evals-routing.sh"
"$SCRIPT_DIR/skill-evals-quality.sh"
"$SCRIPT_DIR/architecture-guidance.sh"
"$SCRIPT_DIR/mutation-workflow.sh"
"$SCRIPT_DIR/tdd-watch-workflow.sh"
"$SCRIPT_DIR/delegation-landing-workflow.sh"
"$SCRIPT_DIR/delegate-command.sh"
"$SCRIPT_DIR/delegate-status.sh"
"$SCRIPT_DIR/delegate-loop.sh"
"$SCRIPT_DIR/stop-hook-delegator-exemption.sh"
"$SCRIPT_DIR/skill-usage.sh"
"$SCRIPT_DIR/install-global.sh"
"$SCRIPT_DIR/upstream-changes.sh"
