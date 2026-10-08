#!/usr/bin/env python3
"""Count how often each craft skill, agent and command was used.

Reads local Claude Code transcripts (~/.claude/projects/**/*.jsonl, including
subagent transcripts) and reports, for every skill, agent and command in the
craft plugin, how many times it was used in the last N days, in how many
sessions, when it was last used, and which other craft files route to it.
It feeds the triage that decides which skills ship and which sit on the
shelf (see PROVENANCE.md); re-run it each quarter.

What counts as a use:
  skill    a Skill tool call naming it, or a /<name> slash command
  agent    an Agent (or Task) tool call with it as subagent_type
  command  a /<name> slash command

`craft:<name>` and a bare `<name>` both count, since a skill installed by
install-rich.sh into ~/.claude/skills has no prefix. A name with any other
prefix (another plugin's `tdd`) does not.

Claude Code deletes transcripts after `cleanupPeriodDays` (30 by default), so
a 90-day window usually covers about 30 days; the report says how far back the
oldest transcript reaches. Raise cleanupPeriodDays in settings.json to keep
more history for a later re-run.

Transcripts live on the machine that ran the session. Run this on each
machine you use, or copy their projects directories together and pass each
with --projects. Cloud sessions keep no transcripts after the container goes.

Usage:
  scripts/skill-usage.py                       # Markdown table, last 90 days
  scripts/skill-usage.py --days 60 --format json
  scripts/skill-usage.py --projects ~/.claude/projects --projects ./laptop-projects
  py scripts\\skill-usage.py --output usage.md   # Windows: avoids PowerShell's UTF-16 `>`
"""

import argparse
import datetime
import json
import os
import re
import sys
from pathlib import Path

PLUGIN = "craft"
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PLUGIN_ROOT = REPO_ROOT
COMMAND_TAG = re.compile(r"<command-name>/?([^<\s]+)</command-name>")


def default_projects():
    config = os.environ.get("CLAUDE_CONFIG_DIR")
    base = Path(config) if config else Path.home() / ".claude"
    return [base / "projects"]


def inventory(plugin_root):
    """Every skill, agent and command in the repository, shipped or on the
    shelf, with the text that can route to other items.

    Skills may sit directly under skills/ (the old flat layout) or in buckets
    (skills/<bucket>/<name>/); shelf/ holds items kept but not shipped."""
    items = []
    roots = [(plugin_root / "skills", True), (plugin_root / "shelf" / "skills", False)]
    for root, shipped in roots:
        if not root.is_dir():
            continue
        for skill_md in sorted(root.rglob("SKILL.md")):
            d = skill_md.parent
            if "deprecated" in d.relative_to(root).parts:
                continue
            text = "\n".join(
                f.read_text(encoding="utf-8", errors="replace")
                for f in sorted(d.rglob("*"))
                if f.is_file() and f.suffix in {".md", ".yaml", ".yml", ""}
            )
            items.append({"kind": "skill", "name": d.name, "text": text, "shipped": shipped})
    for kind, folder in (("agent", "agents"), ("command", "commands")):
        for base, shipped in ((plugin_root, True), (plugin_root / "shelf", False)):
            for f in sorted((base / folder).glob("*.md")):
                items.append({"kind": kind, "name": f.stem, "text": f.read_text(encoding="utf-8", errors="replace"), "shipped": shipped})
    return items


def guidance_texts(plugin_root):
    """Top-level guidance files that route to skills but are not items."""
    return {
        f.name: f.read_text(encoding="utf-8", errors="replace")
        for f in sorted(plugin_root.glob("CLAUDE*.md"))
    }


def routed_by(name, own_label, sources):
    pattern = re.compile(
        r"(?:`(?:%s:)?%s`|%s:%s\b|(?<![\w-])/%s\b)"
        % (PLUGIN, re.escape(name), PLUGIN, re.escape(name), re.escape(name))
    )
    return sorted(label for label, text in sources.items() if label != own_label and pattern.search(text))


def local_name(raw):
    """`craft:tdd` and `tdd` -> `tdd`; any other prefix -> None."""
    prefix, sep, rest = raw.rpartition(":")
    if not sep:
        return raw
    return rest if prefix == PLUGIN else None


def parse_time(value):
    if not isinstance(value, str):
        return None
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict))
    return ""


def events(line):
    """Yield (kind, raw_name) uses found in one transcript record."""
    message = line.get("message") or {}
    content = message.get("content")
    if line.get("type") == "assistant" and isinstance(content, list):
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            args = block.get("input") or {}
            if block.get("name") == "Skill" and isinstance(args.get("skill"), str):
                yield "skill", args["skill"]
            elif block.get("name") in ("Agent", "Task") and isinstance(args.get("subagent_type"), str):
                yield "agent", args["subagent_type"]
    elif line.get("type") == "user":
        for name in COMMAND_TAG.findall(text_of(content)):
            yield "slash", name


def scan(project_dirs, since):
    uses = {}  # (kind, raw name) -> list of (session, time)
    files = 0
    earliest = None
    for root in project_dirs:
        if not root.is_dir():
            print(f"skill-usage: no transcripts at {root}", file=sys.stderr)
            continue
        for path in sorted(root.rglob("*.jsonl")):
            files += 1
            with path.open(encoding="utf-8", errors="replace") as handle:
                for raw in handle:
                    try:
                        line = json.loads(raw)
                    except ValueError:
                        continue
                    if not isinstance(line, dict):
                        continue
                    when = parse_time(line.get("timestamp"))
                    if when is not None and when < since:
                        continue
                    if when is not None and (earliest is None or when < earliest):
                        earliest = when
                    session = line.get("sessionId") or path.stem
                    for kind, name in events(line):
                        uses.setdefault((kind, name), []).append((session, when))
    return uses, files, earliest


def report(plugin_root, project_dirs, days):
    now = datetime.datetime.now(datetime.timezone.utc)
    since = now - datetime.timedelta(days=days)
    items = inventory(plugin_root)
    sources = {i["name"]: i["text"] for i in items}
    sources.update(guidance_texts(plugin_root))
    uses, files, earliest = scan(project_dirs, since)

    def matches(item):
        kinds = {"skill": ("skill", "slash"), "agent": ("agent",), "command": ("slash",)}[item["kind"]]
        return [
            hit
            for (kind, raw), hits in uses.items()
            if kind in kinds and local_name(raw) == item["name"]
            for hit in hits
        ]

    rows = []
    for item in items:
        hits = matches(item)
        times = [t for _, t in hits if t is not None]
        rows.append({
            "kind": item["kind"],
            "name": item["name"],
            "uses": len(hits),
            "sessions": len({s for s, _ in hits}),
            "last_used": max(times).date().isoformat() if times else None,
            "routed_by": routed_by(item["name"], item["name"], sources),
            "shipped": item["shipped"],
        })
    # Routing from CLAUDE.md or from an unused item is no evidence of use; a
    # route from an item that was used is.
    used = {r["name"] for r in rows if r["uses"]}
    for row in rows:
        row["suggest"] = "own" if row["uses"] else ("review" if used & set(row["routed_by"]) else "drop?")
    claimed = {r["name"] for r in rows}

    other = {}
    for (kind, raw), hits in uses.items():
        if kind == "slash":
            continue  # built-in commands (/clear, /model, ...) would drown the list
        if local_name(raw) in claimed:
            continue
        key = f"{kind}:{raw}"
        other[key] = other.get(key, 0) + len(hits)

    order = {"skill": 0, "agent": 1, "command": 2}
    rows.sort(key=lambda r: (order[r["kind"]], -r["uses"], r["name"]))
    return {
        "generated": now.isoformat(timespec="seconds"),
        "days": days,
        "since": since.date().isoformat(),
        "projects": [str(p) for p in project_dirs],
        "plugin_root": str(plugin_root),
        "files": files,
        "earliest": earliest.date().isoformat() if earliest else None,
        "items": rows,
        "other": dict(sorted(other.items(), key=lambda kv: (-kv[1], kv[0]))),
    }


def markdown(r):
    out = [
        f"# craft usage, last {r['days']} days (since {r['since']})",
        "",
        f"{r['files']} transcript files under {', '.join(r['projects'])}; "
        f"the oldest record in the window is from {r['earliest'] or 'nowhere'}.",
        "`suggest`: own = used; review = unused, but a used craft item routes to it; drop? = neither.",
        "",
        "| kind | name | uses | sessions | last used | routed by | suggest | shipped |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in r["items"]:
        routes = row["routed_by"]
        shown = ", ".join(routes[:3]) + (f" +{len(routes) - 3}" if len(routes) > 3 else "")
        out.append(
            f"| {row['kind']} | {row['name']} | {row['uses']} | {row['sessions']} "
            f"| {row['last_used'] or '-'} | {shown or '-'} | {row['suggest']} | {'yes' if row['shipped'] else 'shelf'} |"
        )
    if r["other"]:
        out += ["", "## Used, but not part of craft", "", "| kind:name | uses |", "| --- | --- |"]
        out += [f"| {k} | {v} |" for k, v in list(r["other"].items())[:40]]
    return "\n".join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=int, default=90, help="look-back window (default 90)")
    parser.add_argument("--projects", type=Path, action="append",
                        help="a Claude Code projects directory; repeatable (default ~/.claude/projects)")
    parser.add_argument("--plugin-root", type=Path, default=DEFAULT_PLUGIN_ROOT,
                        help="the repository root holding skills/, agents/, commands/ and shelf/ (default: this repository)")
    parser.add_argument("--format", choices=("md", "json"), default="md")
    parser.add_argument("--output", type=Path, help="write the report here, as UTF-8, instead of stdout")
    args = parser.parse_args(argv)

    result = report(args.plugin_root, args.projects or default_projects(), args.days)
    text = json.dumps(result, indent=2) if args.format == "json" else markdown(result)
    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8")
    else:
        print(text)


if __name__ == "__main__":
    main()
