#!/usr/bin/env bash
#
# flatten-skills.sh SOURCE_ROOT DEST [--with-shelf]
#
# The Claude Agent SDK discovers skills at `<workspace>/.claude/skills/<name>/`,
# one level deep. This repository keeps them in buckets
# (skills/<bucket>/<name>/), so the eval harness copies each shipped skill into
# a flat DEST/<name>/. Deprecated and in-progress skills are left out, as the
# plugin leaves them out; --with-shelf adds shelf/skills/<name>/ for quality
# suites that exercise a shelved skill.

set -euo pipefail

src="${1:?usage: flatten-skills.sh SOURCE_ROOT DEST [--with-shelf]}"
dest="${2:?usage: flatten-skills.sh SOURCE_ROOT DEST [--with-shelf]}"
with_shelf="${3:-}"

mkdir -p "$dest"
for dir in "$src"/skills/*/*/; do
  bucket="$(basename "$(dirname "$dir")")"
  case "$bucket" in deprecated|in-progress) continue ;; esac
  cp -R "${dir%/}" "$dest/"
done
if [ "$with_shelf" = "--with-shelf" ] && [ -d "$src/shelf/skills" ]; then
  for dir in "$src"/shelf/skills/*/; do
    cp -R "${dir%/}" "$dest/"
  done
fi
