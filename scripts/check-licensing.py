#!/usr/bin/env python3
"""Check that licence notices and acknowledgements stay complete.

  - the root LICENSE keeps Paul Hammond's copyright notice, which MIT requires
    because most of craft derives from his work;
  - every nested LICENSE or NOTICE has a row in ACKNOWLEDGEMENTS.md, and every
    notice path that file links to exists;
  - every source-notes.md that names an upstream GitHub repository has a
    LICENSE or NOTICE beside its skill, or states "ideas only, no text copied".

Exit status 1 lists every problem found.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IDEAS_ONLY = "ideas only, no text copied"
UPSTREAM = re.compile(r"https://github\.com/(?!conjurer-rich/|citypaul/)[\w.-]+/[\w.-]+")


def main():
    problems = []
    rel = lambda p: p.relative_to(ROOT).as_posix()

    if "Copyright (c) 2024 Paul Hammond" not in (ROOT / "LICENSE").read_text(encoding="utf-8"):
        problems.append("LICENSE: Paul Hammond's copyright notice is missing")

    acknowledgements = (ROOT / "ACKNOWLEDGEMENTS.md").read_text(encoding="utf-8")
    linked = set(re.findall(r"\]\(([^)#\s]+)\)", acknowledgements))
    for path in sorted(linked):
        if not path.startswith(("http://", "https://")) and not (ROOT / path).exists():
            problems.append(f"ACKNOWLEDGEMENTS.md links to {path}, which does not exist")

    # Shipped and shelved content only: eval and test fixtures carry stand-in
    # licences that are test data, not material this repository redistributes.
    content = [ROOT / d for d in ("skills", "shelf", "agents", "commands", "hooks", "scripts")]
    notices = sorted(
        p for base in content for name in ("LICENSE", "NOTICE") for p in base.glob(f"**/{name}")
    )
    for notice in notices:
        if rel(notice) not in linked:
            problems.append(f"{rel(notice)}: no row in ACKNOWLEDGEMENTS.md")

    for notes in sorted(p for base in content for p in base.glob("**/source-notes.md")):
        skill = notes.parent.parent
        text = notes.read_text(encoding="utf-8")
        if not UPSTREAM.search(text):
            continue
        if (skill / "LICENSE").exists() or (skill / "NOTICE").exists() or IDEAS_ONLY in text:
            continue
        problems.append(f"{rel(notes)}: names an upstream repository but its skill has no LICENSE or NOTICE and it does not say \"{IDEAS_ONLY}\"")

    for problem in problems:
        print(problem)
    if problems:
        print(f"\n{len(problems)} licensing problem(s)", file=sys.stderr)
        return 1
    print("licences and acknowledgements OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
