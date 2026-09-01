#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
installed_cli="$omacos_home/.local/bin/omacos"

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  print "Usage: ./uninstall.sh [--yes] [--remove-packages]"
  print "Stops a shell started from this checkout, or delegates to an installed OMacOS uninstaller."
  exit 0
fi

for uninstall_option in "$@"; do
  case $uninstall_option in
    --yes|-y|--remove-packages) ;;
    *) print -u2 "Unknown uninstall option: $uninstall_option"; exit 1 ;;
  esac
done

if [[ -x $installed_cli ]]; then
  exec "$installed_cli" uninstall "$@"
fi

debug_shell_pattern="$script_directory/.build/.*/omacos-shell"
debug_shell_processes=(${(f)"$(pgrep -f "$debug_shell_pattern" || true)"})

if (( ${#debug_shell_processes} > 0 )); then
  for process_id in "${debug_shell_processes[@]}"; do
    kill "$process_id"
  done
  print "Stopped the OMacOS shell started from this checkout."
else
  print "No installed or locally running OMacOS environment was found."
fi

print "The local Swift build cache remains in $script_directory/.build and does not affect macOS."
