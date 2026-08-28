#!/bin/bash
set -euo pipefail

archive_path=${1:?Usage: audit_release_archive.sh /path/to/Wuzzler.xcarchive}
project_root=$(cd "$(dirname "$0")/.." && pwd)
app_path="$archive_path/Products/Applications/Wuzzler.app"
info_path="$app_path/Info.plist"
privacy_path="$app_path/PrivacyInfo.xcprivacy"
dsym_path="$archive_path/dSYMs/Wuzzler.app.dSYM"

test -d "$app_path"
test -f "$info_path"
test -f "$privacy_path"
test -d "$dsym_path"

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_path")" = "CotterCrystal.Wuzzler"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$info_path")" = "Wuzzler Daily"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_path")" = "1.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$info_path")" = "17.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$info_path")" = "false"

plutil -lint "$privacy_path"
plutil -extract NSPrivacyTracking raw "$privacy_path" | grep -qx false
plutil -extract NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPIType raw "$privacy_path" | grep -qx NSPrivacyAccessedAPICategoryUserDefaults
plutil -extract NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPITypeReasons.0 raw "$privacy_path" | grep -qx CA92.1

for icon in "$project_root"/Wuzzler/Assets.xcassets/AppIcon.appiconset/*.png; do
  test "$(sips -g hasAlpha "$icon" 2>/dev/null | awk '/hasAlpha/{print $2}')" = "no"
done

grep -q '<key>com.apple.developer.game-center</key>' "$project_root/Wuzzler/Wuzzler.entitlements"
echo "Release archive audit passed for $archive_path"
