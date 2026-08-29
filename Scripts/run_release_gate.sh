#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: Scripts/run_release_gate.sh --lane NAME --output-dir DIRECTORY
  [--download-platform]
  [--expected-xcode-build BUILD]
  [--expected-sdk SDK_NAME]
EOF
  exit 64
}

lane=""
output_dir=""
download_platform=false
required_xcode_build=""
required_sdk=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane)
      [[ $# -ge 2 ]] || usage
      lane=$2
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || usage
      output_dir=$2
      shift 2
      ;;
    --download-platform)
      download_platform=true
      shift
      ;;
    --expected-xcode-build)
      [[ $# -ge 2 ]] || usage
      required_xcode_build=$2
      shift 2
      ;;
    --expected-sdk)
      [[ $# -ge 2 ]] || usage
      required_sdk=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

[[ "$lane" =~ ^[A-Za-z0-9._-]+$ && -n "$output_dir" ]] || usage
if [[ -e "$output_dir" ]]; then
  echo "ERROR: output directory already exists: $output_dir" >&2
  exit 1
fi

project_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$project_root"
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

set -o pipefail
{
  sw_vers
  xcodebuild -version
  xcrun swift --version
  xcrun --sdk iphoneos --show-sdk-path
} | tee "$output_dir/toolchain.log"

actual_xcode_build=$(xcodebuild -version | awk '/Build version/ { print $3 }')
actual_sdk="iphoneos$(xcrun --sdk iphoneos --show-sdk-version)"
if [[ -n "$required_xcode_build" && "$actual_xcode_build" != "$required_xcode_build" ]]; then
  echo "ERROR: expected Xcode build $required_xcode_build, found $actual_xcode_build." >&2
  exit 1
fi
if [[ -n "$required_sdk" && "$actual_sdk" != "$required_sdk" ]]; then
  echo "ERROR: expected SDK $required_sdk, found $actual_sdk." >&2
  exit 1
fi

xcodebuild -runFirstLaunch
if [[ "$download_platform" == true ]]; then
  xcodebuild -downloadPlatform iOS | tee "$output_dir/platform-download.log"
fi

python3 -m unittest discover -s Scripts/tests | tee "$output_dir/content-tests.log"
Scripts/validate_puzzles.py --minimum-future-days 30 | tee "$output_dir/content-validation.log"

simulator_specs=$(python3 <<'PY'
import json
import re
import subprocess

def payload(*arguments):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *arguments, "-j"]))

runtimes = [
    runtime for runtime in payload("runtimes")["runtimes"]
    if runtime.get("isAvailable") and runtime.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
]
if not runtimes:
    raise SystemExit("No available iOS Simulator runtime")

def version_tuple(runtime):
    return tuple(int(part) for part in re.findall(r"\d+", runtime.get("version", "0")))

runtime = max(runtimes, key=version_tuple)
device_types = payload("devicetypes")["devicetypes"]

def select(preferred_names, prefix, excluding=()):
    selected = next(
        (item for name in preferred_names for item in device_types if item.get("name") == name and item.get("identifier") not in excluding),
        None,
    )
    if selected is None:
        selected = next(
            (item for item in device_types if item.get("name", "").startswith(prefix) and item.get("identifier") not in excluding),
            None,
        )
    if selected is None:
        raise SystemExit(f"No {prefix} Simulator device type")
    return selected

primary = select(["iPhone 17 Pro", "iPhone 16 Pro", "iPhone 15 Pro"], "iPhone")
compact = select(
    ["iPhone SE (3rd generation)", "iPhone 13 mini", "iPhone 17e", "iPhone 16e"],
    "iPhone",
    {primary["identifier"]},
)
tablet = select(["iPad (A16)", "iPad (10th generation)", "iPad mini (A17 Pro)"], "iPad")

for role, selected in (("primary", primary), ("compact", compact), ("ipad", tablet)):
    print(
        f'{role}|{runtime["identifier"]}|{selected["identifier"]}|'
        f'{runtime.get("version", "unknown")}|{selected["name"]}'
    )
PY
)

primary_runtime_id=""
primary_device_type_id=""
compact_runtime_id=""
compact_device_type_id=""
ipad_runtime_id=""
ipad_device_type_id=""
while IFS='|' read -r role runtime_id device_type_id runtime_version device_name; do
  case "$role" in
    primary)
      primary_runtime_id=$runtime_id
      primary_device_type_id=$device_type_id
      primary_description="$device_name, iOS $runtime_version"
      ;;
    compact)
      compact_runtime_id=$runtime_id
      compact_device_type_id=$device_type_id
      compact_description="$device_name, iOS $runtime_version"
      ;;
    ipad)
      ipad_runtime_id=$runtime_id
      ipad_device_type_id=$device_type_id
      ipad_description="$device_name, iOS $runtime_version"
      ;;
    *) echo "ERROR: unexpected simulator role $role" >&2; exit 1 ;;
  esac
done <<< "$simulator_specs"

simulator_ids=()
primary_simulator_id=$(xcrun simctl create "Wuzzler-CI-${lane}-primary" "$primary_device_type_id" "$primary_runtime_id")
simulator_ids+=("$primary_simulator_id")
compact_simulator_id=$(xcrun simctl create "Wuzzler-CI-${lane}-compact" "$compact_device_type_id" "$compact_runtime_id")
simulator_ids+=("$compact_simulator_id")
ipad_simulator_id=$(xcrun simctl create "Wuzzler-CI-${lane}-ipad" "$ipad_device_type_id" "$ipad_runtime_id")
simulator_ids+=("$ipad_simulator_id")
cleanup() {
  for simulator_id in "${simulator_ids[@]}"; do
    xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT
{
  echo "Primary simulator: $primary_description, $primary_simulator_id"
  echo "Compact smoke simulator: $compact_description, $compact_simulator_id"
  echo "iPad portrait smoke simulator: $ipad_description, $ipad_simulator_id"
} | tee "$output_dir/simulator.log"

xcodebuild -project Wuzzler.xcodeproj -scheme Wuzzler -configuration Release -showBuildSettings \
  > "$output_dir/release-build-settings.log"

xcodebuild test \
  -project Wuzzler.xcodeproj \
  -scheme Wuzzler \
  -destination "platform=iOS Simulator,id=$primary_simulator_id" \
  -resultBundlePath "$output_dir/WuzzlerTests.xcresult" \
  | tee "$output_dir/test.log"

run_ui_smoke() {
  local simulator_id=$1
  local result_name=$2
  local log_name=$3
  local attempt result_path status

  for attempt in 1 2; do
    if [[ $attempt -eq 2 ]]; then
      echo "Retrying $log_name after resetting the simulator." | tee -a "$output_dir/$log_name.log"
      xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
      xcrun simctl erase "$simulator_id"
    fi

    xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$simulator_id" -b
    result_path="$output_dir/${result_name}-attempt${attempt}.xcresult"

    set +e
    xcodebuild test \
      -project Wuzzler.xcodeproj \
      -scheme Wuzzler \
      -destination "platform=iOS Simulator,id=$simulator_id" \
      -only-testing:WuzzlerUITests/AuthGateUITests/testAuthenticatedShellShowsThreeFloatingTabsAndGames \
      -resultBundlePath "$result_path" \
      | tee -a "$output_dir/$log_name.log"
    status=${PIPESTATUS[0]}
    set -e

    if [[ $status -eq 0 ]]; then
      return 0
    fi
  done

  echo "ERROR: $log_name failed twice." >&2
  return "$status"
}

run_ui_smoke "$compact_simulator_id" "CompactSmoke" "compact-smoke"
run_ui_smoke "$ipad_simulator_id" "iPadPortraitSmoke" "ipad-portrait-smoke"

xcodebuild analyze \
  -project Wuzzler.xcodeproj \
  -scheme Wuzzler \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$output_dir/analyze.log"

archive_path="$output_dir/Wuzzler.xcarchive"
xcodebuild archive \
  -project Wuzzler.xcodeproj \
  -scheme Wuzzler \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$output_dir/archive.log"

expected_build=$(xcrun agvtool what-version -terse | sed '/^[[:space:]]*$/d' | sort -u)
if [[ "$expected_build" == *$'\n'* ]] || [[ ! "$expected_build" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: all versioned targets must have one positive integer build number." >&2
  exit 1
fi
expected_xcode_build=$actual_xcode_build
expected_sdk=$actual_sdk

Scripts/audit_release_archive.sh "$archive_path" \
  --expected-build "$expected_build" \
  --expected-xcode-build "$expected_xcode_build" \
  --expected-sdk "$expected_sdk" \
  | tee "$output_dir/archive-audit.log"

echo "Release gate passed for $lane with Xcode build $expected_xcode_build and $expected_sdk."
