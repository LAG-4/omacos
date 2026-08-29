#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-release-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

if [[ ! -x $project_root/.build/release/omacos-shell ]]; then
  swift build --package-path "$project_root" -c release >/dev/null
fi

OMACOS_SKIP_BUILD=true OMACOS_CODESIGN_IDENTITY=- \
  "$project_root/scripts/package-release.zsh" "$temporary_directory/dist" >/dev/null

archive=$(find "$temporary_directory/dist" -maxdepth 1 -name 'OMacOS-*-arm64.zip' -print -quit)
[[ -n $archive && -f $archive.sha256 ]]
(cd "$temporary_directory/dist" && shasum -a 256 -c "${archive:t}.sha256" >/dev/null)
codesign --verify --deep --strict "$temporary_directory/dist/OMacOSShell.app"
release_entitlements="$temporary_directory/release-entitlements.plist"
codesign -d --entitlements "$release_entitlements" --xml "$temporary_directory/dist/OMacOSShell.app" 2>/dev/null
plutil -p "$release_entitlements" | rg -Fq '"com.apple.security.device.audio-input" => true'

notification_output=$(OMACOS_TEST_HOME="$temporary_directory/home" \
  "$temporary_directory/dist/OMacOSShell.app/Contents/MacOS/omacos-shell" --notification-list)
[[ -z $notification_output ]]

permission_output="$temporary_directory/permission-status.json"
"$temporary_directory/dist/OMacOSShell.app/Contents/MacOS/omacos-shell" --permission-status > "$permission_output" &
permission_process=$!
for _ in {1..50}; do
  if ! kill -0 "$permission_process" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if kill -0 "$permission_process" 2>/dev/null; then
  kill "$permission_process" 2>/dev/null || true
  print -u2 'Release package test failed: hardened permission status did not return within five seconds.'
  exit 1
fi
wait "$permission_process"
jq -e '.schemaVersion == 1' "$permission_output" >/dev/null

metadata=${archive%.zip}.json
jq -e --arg archive "${archive:t}" '.schemaVersion == 1 and .architecture == "arm64" and .archive == $archive' "$metadata" >/dev/null

print 'Signed release application packaging test passed'
