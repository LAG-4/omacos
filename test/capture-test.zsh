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

set +e
missing_qr_output=$("$project_root/.build/debug/omacos-shell" --recognize-qr "$temporary_directory/missing.png" 2>&1)
missing_qr_status=$?
set -e

if (( missing_qr_status == 0 )) || [[ $missing_qr_output != *"OMacOS QR recognition failed"* ]]; then
  print -u2 "Capture test failed: invalid QR input was accepted"
  exit 1
fi

fake_shell="$temporary_directory/omacos-shell"
fake_pbcopy="$temporary_directory/pbcopy"
cat > "$fake_shell" <<'EOF'
#!/bin/zsh
if [[ $1 == "--recognize-qr" ]]; then
  print "https://example.test/qr"
elif [[ -n ${OMACOS_FAKE_SHELL_LOG:-} ]]; then
  print -r -- "$*" >> "$OMACOS_FAKE_SHELL_LOG"
fi
EOF
cat > "$fake_pbcopy" <<'EOF'
#!/bin/zsh
cat > "$OMACOS_FAKE_PBCOPY_OUTPUT"
EOF
chmod +x "$fake_shell" "$fake_pbcopy"

qr_output=$(
  OMACOS_CAPTURE_DIRECTORY="$temporary_directory/Screenshots" \
  OMACOS_SCREENCAPTURE_BINARY="$test_directory/fixtures/fake-screencapture.zsh" \
  OMACOS_SHELL_BINARY="$fake_shell" \
  OMACOS_PBCOPY_BINARY="$fake_pbcopy" \
  OMACOS_FAKE_PBCOPY_OUTPUT="$temporary_directory/qr-clipboard" \
  "$project_root/scripts/capture.zsh" qr
)
[[ $qr_output == "https://example.test/qr" ]]
[[ $(<"$temporary_directory/qr-clipboard") == "https://example.test/qr" ]]

webcam_output=$(
  OMACOS_CAPTURE_DIRECTORY="$temporary_directory/Screenshots" \
  OMACOS_SCREENCAPTURE_BINARY="$test_directory/fixtures/fake-screencapture.zsh" \
  OMACOS_SHELL_BINARY="$fake_shell" \
  OMACOS_FAKE_SHELL_LOG="$temporary_directory/webcam-shell.log" \
  OMACOS_FAKE_CAPTURE_LOG="$temporary_directory/webcam-capture.log" \
  OMACOS_WEBCAM_START_DELAY=0 \
  "$project_root/scripts/capture.zsh" recording --webcam
)
[[ -f $webcam_output ]]
rg -Fxq -- '-A' "$temporary_directory/webcam-capture.log"
rg -Fxq -- '-g' "$temporary_directory/webcam-capture.log"
rg -Fxq -- '--webcam-overlay start' "$temporary_directory/webcam-shell.log"
rg -Fxq -- '--webcam-overlay stop' "$temporary_directory/webcam-shell.log"

print "Capture, OCR, and QR command test passed"
