#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: Scripts/prepare_testflight_build.sh BUILD_NUMBER --app-store-confirmed

BUILD_NUMBER must be a positive integer that has been confirmed unused in
App Store Connect and greater than every previously uploaded build number.
EOF
  exit 64
}

requested_build=${1:-}
confirmation=${2:-}

if [[ ! "$requested_build" =~ ^[1-9][0-9]*$ ]] || [[ "$confirmation" != "--app-store-confirmed" ]] || [[ $# -ne 2 ]]; then
  usage
fi

project_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$project_root"

if [[ $(git branch --show-current) != "main" ]]; then
  echo "ERROR: TestFlight candidates must be prepared on main." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n $(git ls-files --others --exclude-standard) ]]; then
  echo "ERROR: commit or remove all worktree changes before preparing a TestFlight build." >&2
  exit 1
fi

git fetch --quiet origin main
local_head=$(git rev-parse HEAD)
remote_head=$(git rev-parse refs/remotes/origin/main)
if [[ "$local_head" != "$remote_head" ]]; then
  echo "ERROR: local main must exactly match origin/main before preparing a build." >&2
  exit 1
fi

current_versions=()
while IFS= read -r version; do
  [[ -n "$version" ]] && current_versions+=("$version")
done < <(xcrun agvtool what-version -terse | sed '/^[[:space:]]*$/d' | sort -u)

if [[ ${#current_versions[@]} -ne 1 ]] || [[ ! ${current_versions[0]} =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: all versioned targets must have one positive integer build number." >&2
  exit 1
fi

current_build=${current_versions[0]}
if (( requested_build < current_build )); then
  echo "ERROR: requested build $requested_build is lower than current build $current_build." >&2
  exit 1
fi

marketing_version=$(xcodebuild -project Wuzzler.xcodeproj -scheme Wuzzler -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }')
if [[ -z "$marketing_version" ]]; then
  echo "ERROR: could not read MARKETING_VERSION." >&2
  exit 1
fi

release_tag="testflight/${marketing_version}.${requested_build}"
if git show-ref --verify --quiet "refs/tags/$release_tag"; then
  echo "ERROR: local tag $release_tag already exists." >&2
  exit 1
fi

set +e
git ls-remote --exit-code --tags origin "refs/tags/$release_tag" >/dev/null 2>&1
remote_tag_status=$?
set -e
if [[ $remote_tag_status -eq 0 ]]; then
  echo "ERROR: remote tag $release_tag already exists." >&2
  exit 1
elif [[ $remote_tag_status -ne 2 ]]; then
  echo "ERROR: could not verify remote tags on origin." >&2
  exit 1
fi

if (( requested_build > current_build )); then
  xcrun agvtool new-version -all "$requested_build" >/dev/null
fi

echo "Prepared Wuzzler Daily ${marketing_version} (${requested_build})."
echo "App Store Connect availability was acknowledged with --app-store-confirmed."
if (( requested_build == current_build )); then
  echo "Build number was already ${requested_build}; no project build-number change was needed."
else
  echo "Commit the build-number change before archiving."
fi
echo "After the release gate passes, tag the exact commit as ${release_tag}."
