#!/bin/bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$project_root"

if ! git diff --quiet || ! git diff --cached --quiet || test -n "$(git ls-files --others --exclude-standard)"; then
  echo "ERROR: commit or remove all worktree changes before preparing a TestFlight build." >&2
  exit 1
fi

xcrun agvtool next-version -all
build_number=$(xcrun agvtool what-version -terse)
echo "Prepared Wuzzler Daily 1.0 ($build_number). Commit the build-number change before archiving."
