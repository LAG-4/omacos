#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-capture-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

capture_log="$temporary_directory/capture-arguments"
capture_output=$(
  OMACOS_CAPTURE_DIRECTORY="$temporary_directory/Screenshots" \
  OMACOS_FAKE_CAPTURE_LOG="$capture_log" \
  OMACOS_SCREENCAPTURE_BINARY="$test_directory/fixtures/fake-screencapture.zsh" \
  "$project_root/scripts/capture.zsh" screenshot --screen
)

if [[ ! -f $capture_output ]] || ! rg -Fxq -- "-x" "$capture_log"; then
  print -u2 "Capture test failed: full-screen capture did not create the expected file"
  exit 1
fi

set +e
missing_image_output=$("$project_root/.build/debug/omacos-shell" --recognize-text "$temporary_directory/missing.png" 2>&1)
missing_image_status=$?
set -e

if (( missing_image_status == 0 )) || [[ $missing_image_output != *"OMacOS text recognition failed"* ]]; then
  print -u2 "Capture test failed: invalid OCR input was accepted"
  exit 1
fi

print "Capture and OCR command test passed"
