#!/usr/bin/env python3
"""Check that craft's skills keep the portability tiers they declare.

Every shipped item has a tier (plans D10), declared in portability.json at the
repository root; an item it does not list is **portable**:

  portable     plain instructions; it works in Claude Code and Codex alike
  degrades     it spawns subagents where the harness has them and runs the
               parts one after another where it does not
  claude-only  it depends on Claude Code tools, agent files or hooks

Checks
  - portability.json names only shipped items;
  - a portable or degrades skill names no Claude Code tool (the Agent, Skill
    or Workflow tool, `subagent_type`, ToolSearch, send_later, create_session,
    ScheduleWakeup) and no `~/.claude` path, except inside a paragraph or list
    item that carries a "Claude Code:" note. Source notes are exempt: they
    describe where text came from, not what to do;
  - a claude-only skill's agents/openai.yaml turns implicit invocation off,
    so Codex never reaches for it;
  - a portable or degrades skill has an agents/openai.yaml, so Codex shows it,
    and a skill with `disable-model-invocation: true` sets
    `allow_implicit_invocation: false` there: Codex reads only the latter;
  - the router, `ask`, marks every claude-only item *(Claude Code)* and every
    degrades item *(subagents)* in the sentence, table cell or list entry that names it.

Exit status 1 lists every problem found.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIERS = ("portable", "degrades", "claude-only")
ROUTER = "ask"
CLAUDE_ONLY_NAMES = re.compile(
    r"\b(?:Agent|Skill|Workflow) tool\b"
    r"|`(?:Agent|Skill|Workflow|ToolSearch|TaskCreate|ScheduleWakeup)`"
    r"|\bsubagent_type\b|\bToolSearch\b|\bsend_later\b|\bcreate_session\b|\bScheduleWakeup\b"
    r"|~/\.claude\b"
)
NOTE = "Claude Code:"
SENTENCE_END = re.compile(r"\.(?:\s|$)|\||\n\n|,\s+(?:and\s+)?(?:the\s+)?`")
USER_INVOKED = re.compile(r"\A---\n(?:.*\n)*?disable-model-invocation:\s*true\s*\n(?:.*\n)*?---\n")
IMPLICIT_OFF = re.compile(r"^\s*allow_implicit_invocation:\s*false\s*$", re.M)
MARK = {"claude-only": "*(Claude Code)*", "degrades": "*(subagents)*"}


def shipped_items(root):
    plugin = json.loads((root / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))
    skills = {Path(p).name: root / p for p in plugin["skills"]}
    others = {md.stem: md for kind in ("agents", "commands") for md in sorted((root / kind).glob("*.md"))}
    return skills, others


def blocks(text):
    """Paragraphs, with each list item its own block."""
    block = []
    for line in text.splitlines():
        starts_item = re.match(r"\s*(?:[-*]|\d+\.)\s", line) is not None
        if not line.strip() or (starts_item and block):
            if block:
                yield "\n".join(block)
            block = [line] if line.strip() else []
        else:
            block.append(line)
    if block:
        yield "\n".join(block)


def check(root):
    problems = []
    declared = json.loads((root / "portability.json").read_text(encoding="utf-8"))
    skills, others = shipped_items(root)
    tier = {}
    for name_tier, names in declared.items():
        if name_tier.startswith("_"):
            continue
        if name_tier not in TIERS:
            problems.append(f"portability.json: unknown tier {name_tier!r}")
            continue
        for name in names:
            if name not in skills and name not in others:
                problems.append(f"portability.json: {name} is not a shipped skill, agent or command")
            tier[name] = name_tier

    for name, folder in sorted(skills.items()):
        if tier.get(name, "portable") == "claude-only":
            openai = folder / "agents" / "openai.yaml"
            if not (openai.is_file() and IMPLICIT_OFF.search(openai.read_text(encoding="utf-8"))):
                problems.append(
                    f"{folder.relative_to(root)}: claude-only skill needs agents/openai.yaml with"
                    " allow_implicit_invocation: false, so Codex never picks it on its own"
                )
            continue
        openai = folder / "agents" / "openai.yaml"
        if not openai.is_file():
            problems.append(f"{folder.relative_to(root)}: {tier.get(name, 'portable')} skill has no agents/openai.yaml")
        elif USER_INVOKED.search((folder / "SKILL.md").read_text(encoding="utf-8")) and not IMPLICIT_OFF.search(
            openai.read_text(encoding="utf-8")
        ):
            problems.append(
                f"{openai.relative_to(root)}: the skill is user-invoked but allow_implicit_invocation is not false"
            )
        for md in sorted(folder.rglob("*.md")):
            if md.name == "source-notes.md":
                continue
            for block in blocks(md.read_text(encoding="utf-8")):
                if NOTE in block:
                    continue
                for match in CLAUDE_ONLY_NAMES.finditer(block):
                    problems.append(
                        f"{md.relative_to(root)}: names {match.group(0)!r} outside a \"{NOTE}\" note"
                        f" in a {tier.get(name, 'portable')} skill"
                    )

    router = skills.get(ROUTER)
    if router is not None:
        text = (router / "SKILL.md").read_text(encoding="utf-8")
        for name, name_tier in sorted(tier.items()):
            if name_tier not in MARK:
                continue
            # The mark belongs to the sentence (or table cell) that names the item.
            sentences = [
                SENTENCE_END.split(text[m.end():], maxsplit=1)[0]
                for m in re.finditer(rf"[`/]{re.escape(name)}\b", text)
            ]
            if not any(MARK[name_tier] in s for s in sentences):
                problems.append(f"{ROUTER}: {name} is {name_tier} but is never marked {MARK[name_tier]}")
    return problems


def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT
    problems = check(root)
    for problem in problems:
        print(problem)
    if problems:
        print(f"\n{len(problems)} portability problem(s)")
        return 1
    print("portability tiers hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
