#!/usr/bin/env bash
#
# Test the delegating-github-issues review-pack script against a fixture
# worktree (test/fixtures/review-pack). The script writes the staged diff, the
# diffstat and the implementer's summary to one file, once per review round,
# so every reviewer reads that file instead of running `git diff` itself.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACK="$REPO_ROOT/skills/delivery/delegating-github-issues/scripts/review-pack"
FIXTURES="$SCRIPT_DIR/fixtures/review-pack"
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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

g() {
  git -C "$WT" -c user.name=fixture -c user.email=fixture@example.com \
    -c commit.gpgsign=false "$@"
}

# A fresh worktree per test: base/ committed, staged/ copied over and staged.
make_worktree() {
  WT="$TMP/wt-$RANDOM$RANDOM"
  mkdir -p "$WT"
  git -C "$WT" init -q
  cp -R "$FIXTURES/base/." "$WT/"
  g add -A
  g commit -q -m base
  cp -R "$FIXTURES/staged/." "$WT/"
  g add -A
  OUT="$TMP/scratch-$RANDOM$RANDOM/7/review-pack.md"
}

pack() {
  "$PACK" --worktree "$WT" --implementer "$FIXTURES/implementer.md" --out "$OUT"
}

# section <heading> <file>: the lines under "## <heading>" up to the next "## ".
section() {
  awk -v h="## $1" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$2" 2>/dev/null || true
}

# --- The pack holds the staged diff, the diffstat and the summary ----------

make_worktree
stdout="$(pack)" || true

if [ -f "$OUT" ]; then
  pass "writes the pack to --out, creating its directory"
else
  fail "writes the pack to --out, creating its directory"
fi

shortstat="$(g diff --cached --shortstat | sed 's/^ *//')"
if section Diffstat "$OUT" | grep -Fxq -- "$shortstat"; then
  pass "the Diffstat section carries git's shortstat line"
else
  fail "the Diffstat section carries git's shortstat line"
fi

if section Diffstat "$OUT" | grep -Eq 'src/greet\.sh +\| +2 [+-]+' \
  && section Diffstat "$OUT" | grep -Eq 'docs/usage\.md +\| +5 \++'; then
  pass "the Diffstat section lists every staged file with its counts"
else
  fail "the Diffstat section lists every staged file with its counts"
fi

if section 'Implementer summary' "$OUT" | grep -Fq '(h) rendered change: no' \
  && section 'Implementer summary' "$OUT" | grep -Fq '# Implementer report for #7'; then
  pass "the Implementer summary section carries the report verbatim"
else
  fail "the Implementer summary section carries the report verbatim"
fi

diff_body="$(section 'Staged diff' "$OUT")"
if printf '%s\n' "$diff_body" | grep -Fxq -- '-  echo "Hello, $1"' \
  && printf '%s\n' "$diff_body" | grep -Fxq -- '+  echo "Hello, ${1:-world}"' \
  && printf '%s\n' "$diff_body" | grep -Fxq -- '+++ b/docs/usage.md'; then
  pass "the Staged diff section carries the full staged diff"
else
  fail "the Staged diff section carries the full staged diff"
fi

if [ "$stdout" = "$OUT: $shortstat" ]; then
  pass "prints one line: the pack's path and the shortstat"
else
  fail "prints one line: the pack's path and the shortstat (got: $stdout)"
fi

# --- The diff fence outlasts any backtick run in the diff ------------------

# docs/usage.md holds a ``` fence; a ``` fence round the diff would close early.
open_fence="$(printf '%s\n' "$diff_body" | grep -m1 '^`' || true)"
close_fence="$(printf '%s\n' "$diff_body" | grep '^`' | tail -n 1)"
if [ "$open_fence" = '````diff' ] && [ "$close_fence" = '````' ]; then
  pass "fences the diff with one more backtick than the longest run inside it"
else
  fail "fences the diff with one more backtick than the longest run inside it (got: $open_fence / $close_fence)"
fi

# --- A diff with no backtick still gets a pack, fenced with three ----------

# Most code diffs hold no backtick at all: only src/greet.sh stays staged.
make_worktree
g reset -q -- docs/usage.md
set +e
stdout="$(pack 2>&1)"
code=$?
set -e
plain_body="$(section 'Staged diff' "$OUT")"
open_fence="$(printf '%s\n' "$plain_body" | grep -m1 '^`' || true)"
close_fence="$(printf '%s\n' "$plain_body" | grep '^`' | tail -n 1 || true)"
if [ "$code" -eq 0 ] && [ -f "$OUT" ] \
  && printf '%s\n' "$plain_body" | grep -Fxq -- '+  echo "Hello, ${1:-world}"'; then
  pass "a diff with no backtick still writes the pack"
else
  fail "a diff with no backtick still writes the pack (exit $code: $stdout)"
fi
if [ "$open_fence" = '```diff' ] && [ "$close_fence" = '```' ]; then
  pass "a diff with no backtick is fenced with exactly three backticks"
else
  fail "a diff with no backtick is fenced with exactly three backticks (got: $open_fence / $close_fence)"
fi

# --- --base: the branch's committed diff, for Land ---------------------------

# The staged change is committed; the pack carries base...HEAD and needs no
# implementer report. A later staged edit is not part of the branch diff.
make_worktree
base_sha="$(g rev-parse HEAD)"
g commit -q -m change
echo 'uncommitted line' >> "$WT/README.md"
g add README.md
set +e
stdout="$("$PACK" --worktree "$WT" --base "$base_sha" --out "$OUT" 2>&1)"
code=$?
set -e
range_shortstat="$(g diff --shortstat "$base_sha...HEAD" | sed 's/^ *//')"
branch_body="$(section 'Branch diff' "$OUT")"
if [ "$code" -eq 0 ] \
  && printf '%s\n' "$branch_body" | grep -Fxq -- '+  echo "Hello, ${1:-world}"' \
  && printf '%s\n' "$branch_body" | grep -Fxq -- '+++ b/docs/usage.md'; then
  pass "--base: the Branch diff section carries base...HEAD"
else
  fail "--base: the Branch diff section carries base...HEAD (exit $code: $stdout)"
fi
if section Diffstat "$OUT" | grep -Fxq -- "$range_shortstat" \
  && [ "$stdout" = "$OUT: $range_shortstat" ]; then
  pass "--base: the diffstat and the printed line measure base...HEAD"
else
  fail "--base: the diffstat and the printed line measure base...HEAD (got: $stdout)"
fi
if [ ! -f "$OUT" ] || grep -Fq 'uncommitted line' "$OUT" || grep -Fxq '## Staged diff' "$OUT" \
  || grep -Fxq '## Implementer summary' "$OUT"; then
  fail "--base: no staged diff and no implementer section"
else
  pass "--base: no staged diff and no implementer section"
fi
if printf '%s\n' "$branch_body" | grep -m1 '^`' | grep -Fxq '````diff'; then
  pass "--base: the fence outlasts the backtick runs in the branch diff"
else
  fail "--base: the fence outlasts the backtick runs in the branch diff"
fi

make_worktree
g commit -q -m change
set +e
"$PACK" --worktree "$WT" --base HEAD --out "$OUT" > /dev/null 2>&1
code=$?
set -e
if [ "$code" -eq 3 ] && [ ! -e "$OUT" ]; then
  pass "--base: an empty range exits 3 and writes no pack"
else
  fail "--base: an empty range exits 3 and writes no pack (exit $code)"
fi

# --- --merge: a staged conflict resolution, for Land and Sync ---------------

# The branch and main both change greet.sh's echo line, so the merge
# conflicts there; main also adds a file the branch never touched.
make_merge_worktree() {
  make_worktree
  g commit -q -m change
  g checkout -q -b main-side HEAD~1
  printf '#!/usr/bin/env bash\ngreet() {\n  echo "Hi, $1"\n}\n' > "$WT/src/greet.sh"
  echo 'incoming from main' > "$WT/incoming.txt"
  g add -A
  g commit -q -m main-change
  g checkout -q -
  g merge -q main-side > /dev/null 2>&1 || true
  printf '#!/usr/bin/env bash\ngreet() {\n  echo "Hi, ${1:-world}"\n}\n' > "$WT/src/greet.sh"
  g add src/greet.sh
}

make_merge_worktree
set +e
stdout="$("$PACK" --worktree "$WT" --merge --out "$OUT" 2>&1)"
code=$?
set -e
merge_body="$(section 'Merge resolution' "$OUT")"
if [ "$code" -eq 0 ] \
  && printf '%s\n' "$merge_body" | grep -Fxq -- '-  echo "Hello, ${1:-world}"' \
  && printf '%s\n' "$merge_body" | grep -Fxq -- '-  echo "Hi, $1"' \
  && printf '%s\n' "$merge_body" | grep -Fxq -- '+  echo "Hi, ${1:-world}"'; then
  pass "--merge: the Merge resolution section compares the resolved file with both sides"
else
  fail "--merge: the Merge resolution section compares the resolved file with both sides (exit $code: $stdout)"
fi
if [ ! -f "$OUT" ] || grep -Fq 'incoming' "$OUT" || grep -Fq 'docs/usage.md' "$OUT" \
  || grep -Fxq '## Staged diff' "$OUT"; then
  fail "--merge: files only one side changed stay out of the pack"
else
  pass "--merge: files only one side changed stay out of the pack"
fi

make_merge_worktree
set +e
"$PACK" --worktree "$WT" --base "$(g merge-base HEAD MERGE_HEAD)" --merge --out "$OUT" > /dev/null 2>&1
code=$?
set -e
if [ "$code" -eq 0 ] && grep -Fxq '## Branch diff' "$OUT" && grep -Fxq '## Merge resolution' "$OUT"; then
  pass "--base with --merge: the pack carries both the branch diff and the resolution"
else
  fail "--base with --merge: the pack carries both the branch diff and the resolution (exit $code)"
fi

make_worktree
set +e
err="$("$PACK" --worktree "$WT" --merge --out "$OUT" 2>&1 > /dev/null)"
code=$?
set -e
if [ "$code" -eq 3 ] && [ ! -e "$OUT" ] && [ "$err" = "review-pack: no merge in progress in $WT" ]; then
  pass "--merge with no merge in progress: exits 3 and writes no pack"
else
  fail "--merge with no merge in progress: exits 3 and writes no pack (exit $code)"
fi

# --- Only the staged diff: unstaged edits stay out --------------------------

make_worktree
echo 'unstaged line' >> "$WT/README.md"
pack > /dev/null || true
if [ ! -f "$OUT" ] || grep -Fq 'unstaged line' "$OUT" || grep -Fq 'README.md' "$OUT"; then
  fail "leaves unstaged edits out of the pack"
else
  pass "leaves unstaged edits out of the pack"
fi

# --- A stale pack from an earlier round is replaced -------------------------

make_worktree
mkdir -p "$(dirname "$OUT")"
echo 'stale round 1 pack' > "$OUT"
pack > /dev/null || true
if grep -Fq 'stale round 1 pack' "$OUT"; then
  fail "overwrites the pack from an earlier round"
else
  pass "overwrites the pack from an earlier round"
fi

# --- Refusals ---------------------------------------------------------------

make_worktree
g reset -q
set +e
pack > /dev/null 2>&1
code=$?
set -e
if [ "$code" -eq 3 ] && [ ! -e "$OUT" ]; then
  pass "nothing staged: exits 3 and writes no pack"
else
  fail "nothing staged: exits 3 and writes no pack (exit $code)"
fi

make_worktree
set +e
"$PACK" --worktree "$WT" --implementer "$TMP/missing.md" --out "$OUT" > /dev/null 2>&1
code=$?
set -e
if [ "$code" -eq 2 ] && [ ! -e "$OUT" ]; then
  pass "missing implementer report: exits 2 and writes no pack"
else
  fail "missing implementer report: exits 2 and writes no pack (exit $code)"
fi

set +e
"$PACK" --worktree "$WT" --out "$OUT" > /dev/null 2>&1
code=$?
set -e
if [ "$code" -eq 2 ] && [ ! -e "$OUT" ]; then
  pass "missing argument: exits 2 and writes no pack"
else
  fail "missing argument: exits 2 and writes no pack (exit $code)"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}$FAILURES review-pack check(s) failed${NC}"
  exit 1
fi
echo -e "${GREEN}All review-pack checks passed${NC}"
