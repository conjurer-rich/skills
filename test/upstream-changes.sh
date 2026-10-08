#!/usr/bin/env bash
#
# scripts/upstream-changes lists what changed in each watched upstream since
# a revision, grouped by skill, agent or command, and says which craft item
# each one corresponds to. This test runs it against a throwaway git repo.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGES="$REPO_ROOT/scripts/upstream-changes"
FAILURES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git_in() { git -C "$1" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false "${@:2}"; }

# An upstream with a watched skills/engineering folder.
up="$work/upstream"
mkdir -p "$up/skills/engineering/tdd" "$up/skills/engineering/code-review" \
  "$up/skills/engineering/setup-matt-pocock-skills"
git init -q -b main "$up"
echo v1 > "$up/skills/engineering/tdd/SKILL.md"
echo v1 > "$up/skills/engineering/code-review/SKILL.md"
echo v1 > "$up/skills/engineering/setup-matt-pocock-skills/SKILL.md"
echo v1 > "$up/README.md"
git_in "$up" add -A && git_in "$up" commit -qm "baseline"
baseline="$(git -C "$up" rev-parse HEAD)"

echo v2 > "$up/skills/engineering/tdd/SKILL.md"
git_in "$up" commit -qam "tdd: sharper red step"
middle="$(git -C "$up" rev-parse HEAD)"
echo v2 > "$up/skills/engineering/code-review/SKILL.md"
mkdir -p "$up/skills/engineering/brand-new"
echo v1 > "$up/skills/engineering/brand-new/SKILL.md"
echo v2 > "$up/skills/engineering/setup-matt-pocock-skills/SKILL.md"
git_in "$up" add -A && git_in "$up" commit -qm "review axes, a new skill, setup tweak"
echo v2 > "$up/README.md"
git_in "$up" commit -qam "readme only"
head="$(git -C "$up" rev-parse HEAD)"

cat > "$work/sources.json" <<EOF
{"sources": [{"repo": "example/skills", "branch": "main", "paths": ["skills/engineering"], "baseline": "$baseline"}]}
EOF
cat > "$work/skill-map.json" <<'EOF'
{"example/skills": {"code-review": "review", "setup-matt-pocock-skills": null}}
EOF

run() {
  python3 "$CHANGES" --sources "$work/sources.json" --skill-map "$work/skill-map.json" \
    --source-dir "example/skills=$up" --plugin-root "$REPO_ROOT" "$@"
}

json="$(run --format json)"
check() { # description python-expression-over-`s` (the one source)
  if python3 -c "import json,sys; s=json.loads(sys.argv[1])['sources'][0]; sys.exit(0 if ($2) else 1)" "$json"; then
    pass "$1"
  else
    fail "$1"
  fi
}
unit='(lambda n: next((u for u in s["units"] if u["unit"] == n), None))'

check "the range starts at the baseline" "s['from'] == '$baseline'"
check "the range ends at the branch head" "s['to'] == '$head'"
check "only commits touching watched paths are listed" "[c['subject'] for c in s['commits']] == ['review axes, a new skill, setup tweak', 'tdd: sharper red step']"
check "a same-named craft skill is a counterpart" "$unit('tdd')['local'] == 'tdd' and $unit('tdd')['kind'] == 'counterpart'"
check "a mapped name is a counterpart of its craft skill" "$unit('code-review')['local'] == 'review' and $unit('code-review')['kind'] == 'counterpart'"
check "an unknown skill is new" "$unit('brand-new')['kind'] == 'new' and $unit('brand-new')['local'] is None"
check "a unit mapped to null is not relevant" "$unit('setup-matt-pocock-skills')['kind'] == 'ignored'"
check "changes outside watched paths are left out" "$unit('README.md') is None"
check "each unit lists its changed files" "$unit('tdd')['files'] == ['skills/engineering/tdd/SKILL.md']"
check "changed is true when anything changed" "s['changed'] is True"

json="$(run --format json --since "example/skills=$middle")"
check "--since overrides the baseline" "s['from'] == '$middle' and $unit('tdd') is None and $unit('code-review') is not None"

json="$(run --format json --since "example/skills=$head")"
check "nothing since the head means nothing changed" "s['changed'] is False and s['units'] == [] and s['commits'] == []"

md="$(run)"
if grep -q '## example/skills' <<< "$md" && grep -q '| `code-review` | counterpart | `review` |' <<< "$md"; then
  pass "the default Markdown report has a section and a row per unit"
else
  echo "$md"
  fail "the default Markdown report has a section and a row per unit"
fi
if grep -q "upstream-watch: {\"example/skills\": \"$head\"}" <<< "$md"; then
  pass "the report ends with the reviewed-up-to marker"
else
  fail "the report ends with the reviewed-up-to marker"
fi

if python3 "$CHANGES" --sources "$work/sources.json" --skill-map "$work/skill-map.json" \
  --source-dir "example/skills=$up" --plugin-root "$REPO_ROOT" --since "example/skills=deadbeef" > /dev/null 2>&1; then
  fail "an unknown revision is an error"
else
  pass "an unknown revision is an error"
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All tests passed${NC}"
