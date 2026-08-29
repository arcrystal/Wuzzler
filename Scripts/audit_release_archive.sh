#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: Scripts/audit_release_archive.sh ARCHIVE \
  --expected-build BUILD_NUMBER \
  --expected-xcode-build XCODE_BUILD \
  --expected-sdk SDK_NAME \
  [--require-signed]

Example SDK names: iphoneos26.5, iphoneos27.0
EOF
  exit 64
}

archive_path=${1:-}
[[ -n "$archive_path" ]] || usage
shift

expected_build=""
expected_xcode_build=""
expected_sdk=""
require_signed=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-build)
      [[ $# -ge 2 ]] || usage
      expected_build=$2
      shift 2
      ;;
    --expected-xcode-build)
      [[ $# -ge 2 ]] || usage
      expected_xcode_build=$2
      shift 2
      ;;
    --expected-sdk)
      [[ $# -ge 2 ]] || usage
      expected_sdk=$2
      shift 2
      ;;
    --require-signed)
      require_signed=true
      shift
      ;;
    *) usage ;;
  esac
done

[[ "$expected_build" =~ ^[1-9][0-9]*$ ]] || usage
[[ -n "$expected_xcode_build" && -n "$expected_sdk" ]] || usage

project_root=$(cd "$(dirname "$0")/.." && pwd)
app_path="$archive_path/Products/Applications/Wuzzler.app"
binary_path="$app_path/Wuzzler"
info_path="$app_path/Info.plist"
privacy_path="$app_path/PrivacyInfo.xcprivacy"
dsym_path="$archive_path/dSYMs/Wuzzler.app.dSYM"
dsym_binary="$dsym_path/Contents/Resources/DWARF/Wuzzler"

test -d "$app_path"
test -f "$binary_path"
test -f "$info_path"
test -f "$privacy_path"
test -d "$dsym_path"
test -f "$dsym_binary"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$info_path"
}

test "$(plist_value CFBundleIdentifier)" = "CotterCrystal.Wuzzler"
test "$(plist_value CFBundleDisplayName)" = "Wuzzler Daily"
test "$(plist_value CFBundleShortVersionString)" = "1.0"
test "$(plist_value CFBundleVersion)" = "$expected_build"
test "$(plist_value MinimumOSVersion)" = "17.0"
test "$(plist_value ITSAppUsesNonExemptEncryption)" = "false"
test "$(plist_value DTXcodeBuild)" = "$expected_xcode_build"
test "$(plist_value DTSDKName)" = "$expected_sdk"

architectures=$(lipo -archs "$binary_path")
test "$architectures" = "arm64"

binary_uuids=$(mktemp)
dsym_uuids=$(mktemp)
entitlements_path=$(mktemp)
profile_path=$(mktemp)
cleanup() {
  rm -f "$binary_uuids" "$dsym_uuids" "$entitlements_path" "$profile_path"
}
trap cleanup EXIT

dwarfdump --uuid "$binary_path" | sed -E 's#^UUID: ([^ ]+) \(([^)]+)\).*$#\1 \2#' | sort > "$binary_uuids"
dwarfdump --uuid "$dsym_binary" | sed -E 's#^UUID: ([^ ]+) \(([^)]+)\).*$#\1 \2#' | sort > "$dsym_uuids"
test -s "$binary_uuids"
cmp -s "$binary_uuids" "$dsym_uuids"

plutil -lint "$privacy_path" >/dev/null
plutil -extract NSPrivacyTracking raw "$privacy_path" | grep -qx false
plutil -extract NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPIType raw "$privacy_path" | grep -qx NSPrivacyAccessedAPICategoryUserDefaults
plutil -extract NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPITypeReasons.0 raw "$privacy_path" | grep -qx CA92.1

for icon in "$project_root"/Wuzzler/Assets.xcassets/AppIcon.appiconset/*.png; do
  test "$(sips -g hasAlpha "$icon" 2>/dev/null | awk '/hasAlpha/{print $2}')" = "no"
done

grep -q '<key>com.apple.developer.game-center</key>' "$project_root/Wuzzler/Wuzzler.entitlements"

if [[ "$require_signed" == true ]]; then
  embedded_profile="$app_path/embedded.mobileprovision"
  test -f "$embedded_profile"
  codesign --verify --deep --strict "$app_path"
  codesign -d --entitlements :- "$app_path" > "$entitlements_path" 2>/dev/null
  plutil -lint "$entitlements_path" >/dev/null
  test "$(plutil -extract com.apple.developer.team-identifier raw "$entitlements_path")" = "VD6A5NU7DP"
  test "$(plutil -extract application-identifier raw "$entitlements_path")" = "VD6A5NU7DP.CotterCrystal.Wuzzler"
  test "$(plutil -extract com.apple.developer.game-center raw "$entitlements_path")" = "true"
  test "$(plutil -extract get-task-allow raw "$entitlements_path")" = "false"

  security cms -D -i "$embedded_profile" > "$profile_path"
  plutil -lint "$profile_path" >/dev/null
  test "$(plutil -extract TeamIdentifier.0 raw "$profile_path")" = "VD6A5NU7DP"
  test "$(plutil -extract Entitlements.application-identifier raw "$profile_path")" = "VD6A5NU7DP.CotterCrystal.Wuzzler"
  test "$(plutil -extract Entitlements.com.apple.developer.game-center raw "$profile_path")" = "true"
  test "$(plutil -extract Entitlements.get-task-allow raw "$profile_path")" = "false"
  if /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$profile_path" >/dev/null 2>&1; then
    echo "ERROR: development and ad hoc profiles are not valid for this archive." >&2
    exit 1
  fi
  if /usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$profile_path" >/dev/null 2>&1; then
    echo "ERROR: enterprise profiles are not valid for this archive." >&2
    exit 1
  fi
  python3 - "$profile_path" <<'PY'
import datetime
import plistlib
import sys

with open(sys.argv[1], "rb") as profile_file:
    profile = plistlib.load(profile_file)

expiration = profile["ExpirationDate"]
now = datetime.datetime.now(datetime.timezone.utc)
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=datetime.timezone.utc)
if expiration <= now:
    raise SystemExit("Provisioning profile is expired")
PY
fi

echo "Release archive audit passed for $archive_path"
echo "Build: $expected_build; Xcode build: $expected_xcode_build; SDK: $expected_sdk; architecture: arm64"
if [[ "$require_signed" == true ]]; then
  echo "App Store signature/profile, get-task-allow=false, team, application identifier, Game Center entitlement, and profile expiry passed."
else
  echo "Signature checks skipped for this unsigned CI archive."
fi
