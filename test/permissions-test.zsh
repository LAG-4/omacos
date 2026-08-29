#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-permissions-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
open_log="$temporary_home/open.log"

permission_status=$(OMACOS_SHELL_BINARY="$project_root/.build/debug/omacos-shell" "$project_root/scripts/permissions.zsh" status)
jq -e '
  .schemaVersion == 1
  and ([.accessibility, .screenRecording, .inputMonitoring, .microphone, .camera, .speechRecognition]
    | map(IN("granted", "not-granted", "denied", "restricted", "not-determined", "unknown"))
    | all)
' <<< "$permission_status" >/dev/null

OMACOS_FAKE_OPEN_LOG="$open_log" \
  OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
  "$project_root/scripts/permissions.zsh" open screen-recording
rg -Fq 'Privacy_ScreenCapture' "$open_log"

OMACOS_FAKE_OPEN_LOG="$open_log" \
  OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
  "$project_root/scripts/permissions.zsh" open camera
rg -Fq 'Privacy_Camera' "$open_log"

"$project_root/scripts/permissions.zsh" guide | rg -Fq 'cannot and will not bypass macOS privacy approval'

print 'macOS permission status and settings routing tests passed'
