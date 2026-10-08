#!/usr/bin/env python3
"""Check that the plugin's layout and cross-references hold together.

Layout
  - every skills/<bucket>/<name>/SKILL.md outside deprecated/ and in-progress/
    is listed in .claude-plugin/plugin.json `skills`, and every listed path
    has a SKILL.md;
  - each SKILL.md's frontmatter `name` matches its folder;
  - no name is used twice across shipped, shelved and deprecated items.

References, from shipped files only (skills/<bucket>/..., agents/, commands/)
  - every relative Markdown link resolves to a file or folder;
  - nothing names a shelved or deprecated item (`craft:<name>`, `<name>` in
    backticks, or a `/<name>` command). Shelved items are not installed, so a
    shipped skill that routes to one sends the agent nowhere.

Exit status 1 lists every problem found.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
NOT_SHIPPED_BUCKETS = {"deprecated", "in-progress"}


def frontmatter_name(skill_md):
    match = re.search(r"^name:\s*(.+)$", skill_md.read_text(encoding="utf-8"), re.M)
    return match.group(1).strip().strip("\"'") if match else None


def inventory():
    shipped, unshipped = {}, {}
    for md in sorted((ROOT / "skills").glob("*/*/SKILL.md")):
        bucket = md.parent.parent.name
        (unshipped if bucket in NOT_SHIPPED_BUCKETS else shipped).setdefault(md.parent.name, []).append(md.parent)
    for md in sorted((ROOT / "shelf" / "skills").glob("*/SKILL.md")):
        unshipped.setdefault(md.parent.name, []).append(md.parent)
    for kind in ("agents", "commands"):
        for md in sorted((ROOT / kind).glob("*.md")):
            shipped.setdefault(md.stem, []).append(md)
        for md in sorted((ROOT / "shelf" / kind).glob("*.md")):
            unshipped.setdefault(md.stem, []).append(md)
    return shipped, unshipped


def shipped_files():
    for bucket in sorted((ROOT / "skills").iterdir()):
        if bucket.is_dir() and bucket.name not in NOT_SHIPPED_BUCKETS:
            yield from sorted(p for p in bucket.rglob("*.md"))
    for kind in ("agents", "commands"):
        yield from sorted((ROOT / kind).glob("*.md"))


def main():
    problems = []
    rel = lambda p: p.relative_to(ROOT).as_posix()

    manifest = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))
    listed = {(ROOT / p).resolve() for p in manifest.get("skills", [])}
    shipped, unshipped = inventory()
    for name, paths in shipped.items():
        for path in paths:
            if path.is_dir() and path.resolve() not in listed:
                problems.append(f"{rel(path)}: not listed in plugin.json skills")
    for path in sorted(listed):
        if not (path / "SKILL.md").is_file():
            problems.append(f"plugin.json lists {path.relative_to(ROOT).as_posix()}, which has no SKILL.md")
    for name, paths in {**shipped, **unshipped}.items():
        all_paths = shipped.get(name, []) + unshipped.get(name, [])
        if len(all_paths) > 1:
            problems.append(f"name `{name}` is used by {', '.join(rel(p) for p in all_paths)}")
        for path in paths:
            if path.is_dir():
                declared = frontmatter_name(path / "SKILL.md")
                if declared != name:
                    problems.append(f"{rel(path)}/SKILL.md: frontmatter name `{declared}` does not match its folder")

    gone = sorted(unshipped, key=len, reverse=True)
    gone_pattern = re.compile(
        r"(?:craft:(%s)\b|`(%s)`|(?<![\w/.-])/(%s)\b)" % (("|".join(map(re.escape, gone)),) * 3)
    ) if gone else None
    for md in shipped_files():
        text = md.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), 1):
            for target in LINK.findall(line):
                if re.match(r"^(?:[a-z]+:|#|<)", target) or "${" in target:
                    continue
                path = target.split("#", 1)[0]
                if path and not (md.parent / path).exists():
                    problems.append(f"{rel(md)}:{lineno}: broken link {target}")
            if gone_pattern:
                for match in gone_pattern.finditer(line):
                    name = next(g for g in match.groups() if g)
                    problems.append(f"{rel(md)}:{lineno}: names `{name}`, which is not shipped")

    for problem in problems:
        print(problem)
    if problems:
        print(f"\n{len(problems)} layout or reference problem(s)", file=sys.stderr)
        return 1
    print("layout and references OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
