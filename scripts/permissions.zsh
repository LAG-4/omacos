#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
shell_binary=${OMACOS_SHELL_BINARY:-$omacos_home/.local/bin/omacos-shell}
open_command=${OMACOS_OPEN_BINARY:-/usr/bin/open}
[[ -x $shell_binary ]] || shell_binary="$project_root/.build/debug/omacos-shell"

case ${1:-status} in
  status)
    [[ -x $shell_binary ]] || { print -u2 "OMacOS native shell is unavailable: $shell_binary"; exit 1; }
    "$shell_binary" --permission-status
    ;;
  open)
    case ${2:-privacy} in
      accessibility) pane='Privacy_Accessibility' ;;
      screen-recording) pane='Privacy_ScreenCapture' ;;
      input-monitoring) pane='Privacy_ListenEvent' ;;
      microphone) pane='Privacy_Microphone' ;;
      camera) pane='Privacy_Camera' ;;
      speech-recognition) pane='Privacy_SpeechRecognition' ;;
      privacy) "$open_command" 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'; exit ;;
      *) print -u2 'Usage: omacos permissions open <accessibility|screen-recording|input-monitoring|microphone|camera|speech-recognition|privacy>'; exit 1 ;;
    esac
    "$open_command" "x-apple.systempreferences:com.apple.preference.security?$pane"
    ;;
  guide)
    cat <<'EOF'
OMacOS cannot and will not bypass macOS privacy approval.

Accessibility      AeroSpace focus/move, OMacOS paste, and native window actions
Input Monitoring   Karabiner-Elements Right Option Super layer
Screen Recording   screenshots, recording, OCR, and QR recognition
Microphone         local dictation and microphone recording
Camera             native webcam recording overlay
Speech Recognition on-device dictation transcription

Use `omacos permissions status` to inspect OMacOS itself and
`omacos permissions open NAME` to open the matching System Settings pane.
Karabiner-Elements has its own Input Monitoring identity and must be checked in
System Settings separately.
EOF
    ;;
  *) print -u2 'Usage: omacos permissions <status|open NAME|guide>'; exit 1 ;;
esac
