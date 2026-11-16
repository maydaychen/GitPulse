#!/bin/bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
OUT_DIR=${1:-/tmp/teapulse-github-public}

if [ -e "$OUT_DIR" ]; then
  echo "Removing existing export directory: $OUT_DIR"
  rm -rf "$OUT_DIR"
fi

mkdir -p "$OUT_DIR"

git -C "$REPO_ROOT" archive --format=tar HEAD \
  -- . \
  ':(exclude).harness' \
  ':(exclude)AGENTS.md' \
  ':(exclude)ROADMAP.md' \
  ':(exclude)scripts/harness' \
  ':(exclude)scripts/verify-before-push.sh' \
  | tar -x -C "$OUT_DIR"

git -C "$OUT_DIR" init -b main >/dev/null
git -C "$OUT_DIR" config user.name "${GIT_AUTHOR_NAME:-TeaPulse Maintainer}"
git -C "$OUT_DIR" config user.email "${GIT_AUTHOR_EMAIL:-maintainer@example.com}"
git -C "$OUT_DIR" add -A
git -C "$OUT_DIR" commit -q -m "Initial public release of TeaPulse (GPL-3.0)"

echo "Clean open-source snapshot created at: $OUT_DIR"
echo "Files tracked: $(git -C "$OUT_DIR" ls-files | wc -l | tr -d ' ')"
