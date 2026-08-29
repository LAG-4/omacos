#!/bin/zsh

set -euo pipefail

osascript_command=${OMACOS_OSASCRIPT_BINARY:-/usr/bin/osascript}
ps_command=${OMACOS_PS_BINARY:-/bin/ps}
pgrep_command=${OMACOS_PGREP_BINARY:-/usr/bin/pgrep}
lsof_command=${OMACOS_LSOF_BINARY:-/usr/sbin/lsof}

frontmost_pid=${OMACOS_FRONTMOST_PID:-}
if [[ -z $frontmost_pid ]]; then
  frontmost_pid=$(
    "$osascript_command" -e 'tell application "System Events" to unix id of first application process whose frontmost is true'
  )
fi

[[ $frontmost_pid == <-> ]] || {
  print -u2 "Could not identify the focused application."
  exit 1
}

frontmost_process_name=${OMACOS_FRONTMOST_PROCESS_NAME:-}
if [[ -z $frontmost_process_name ]]; then
  frontmost_process_name=$("$ps_command" -p "$frontmost_pid" -o comm=)
fi

case ${frontmost_process_name:l} in
  *ghostty*|*terminal*|*iterm*|*wezterm*|*kitty*|*alacritty*) ;;
  *)
    print -u2 "The focused application is not a supported terminal: $frontmost_process_name"
    exit 1
    ;;
esac

processes=("$frontmost_pid")
process_index=1
focused_directory=""

while (( process_index <= ${#processes} )); do
  process_id=${processes[$process_index]}
  (( process_index += 1 ))

  lsof_output=$("$lsof_command" -a -d cwd -Fn -p "$process_id" 2>/dev/null || true)
  while IFS= read -r lsof_line; do
    if [[ $lsof_line == n* ]]; then
      candidate_directory=${lsof_line#n}
      if [[ -d $candidate_directory && $candidate_directory != "/" ]]; then
        focused_directory=$candidate_directory
      fi
    fi
  done <<< "$lsof_output"

  child_output=$("$pgrep_command" -P "$process_id" 2>/dev/null || true)
  while IFS= read -r child_id; do
    if [[ $child_id == <-> ]]; then
      processes+=("$child_id")
    fi
  done <<< "$child_output"
done

if [[ -z $focused_directory ]]; then
  print -u2 "Could not resolve a terminal working directory."
  exit 1
fi

print -r -- "$focused_directory"
