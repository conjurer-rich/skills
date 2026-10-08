#!/usr/bin/env python3
"""Install craft into a throwaway Codex home and check what the model sees.

Codex installs craft from the same .claude-plugin/ manifests as Claude Code.
This adds this checkout as a marketplace, installs craft@conjurer, renders the
model-visible prompt with `codex debug prompt-input`, and compares the craft
skills it lists with what the repository says Codex should offer on its own:
every shipped skill except the claude-only ones (portability.json) and the
user-invoked ones (`disable-model-invocation: true`), which Codex hides through
`allow_implicit_invocation: false`.

No login is needed. Usage:
  scripts/check-codex-install.py                     # `codex` on PATH
  scripts/check-codex-install.py npx --yes @openai/codex@0.161.0
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def expected_skills():
    plugin = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))
    tiers = json.loads((ROOT / "portability.json").read_text(encoding="utf-8"))
    claude_only = set(tiers.get("claude-only", []))
    names = set()
    for path in plugin["skills"]:
        folder = ROOT / path
        text = (folder / "SKILL.md").read_text(encoding="utf-8")
        front = text.split("\n---\n", 1)[0]
        if folder.name in claude_only or re.search(r"^disable-model-invocation:\s*true\s*$", front, re.M):
            continue
        names.add(folder.name)
    return names


def main():
    codex = sys.argv[1:] or ["codex"]
    with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as project:
        env = {**os.environ, "CODEX_HOME": home}

        def run(*args, cwd=None):
            result = subprocess.run([*codex, *args], env=env, cwd=cwd, capture_output=True, text=True)
            if result.returncode != 0:
                sys.exit(f"`codex {' '.join(args)}` failed:\n{result.stderr[-2000:]}")
            return result.stdout

        run("plugin", "marketplace", "add", str(ROOT))
        run("plugin", "add", "craft@conjurer")
        subprocess.run(["git", "init", "-q", project], check=True)
        prompt = run("debug", "prompt-input", "hello", cwd=project)

    seen = set(re.findall(r"craft:([a-z0-9-]+)", prompt))
    expected = expected_skills()
    problems = [f"Codex does not offer {name}" for name in sorted(expected - seen)]
    problems += [f"Codex offers {name} on its own, but it is claude-only or user-invoked" for name in sorted(seen - expected)]
    for problem in problems:
        print(problem)
    if problems:
        return 1
    print(f"Codex installs craft and offers its {len(seen)} model-invoked skills")
    return 0


if __name__ == "__main__":
    sys.exit(main())
