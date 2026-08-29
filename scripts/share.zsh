#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
open_command=${OMACOS_OPEN_BINARY:-/usr/bin/open}
osascript_command=${OMACOS_OSASCRIPT:-/usr/bin/osascript}
airdrop_app=${OMACOS_AIRDROP_APP:-/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app}
pbpaste_command=${OMACOS_PBPASTE:-/usr/bin/pbpaste}
share_directory="$omacos_home/.local/state/omacos/share"

choose_file() {
  "$osascript_command" -e 'POSIX path of (choose file with prompt "Choose a file to share")'
}

choose_folder() {
  "$osascript_command" -e 'POSIX path of (choose folder with prompt "Choose a folder to share")'
}

share_path() {
  local path=$1
  [[ -e $path ]] || { print -u2 "Share target does not exist: $path"; return 1; }
  "$open_command" -a "$airdrop_app" "$path"
  print "Opened AirDrop for $path"
}

case ${1:-receive} in
  clipboard)
    mkdir -p "$share_directory"
    clipboard_path="$share_directory/Clipboard.txt"
    "$pbpaste_command" > "$clipboard_path"
    [[ -s $clipboard_path ]] || { print -u2 "The clipboard does not contain shareable text."; exit 1; }
    share_path "$clipboard_path"
    ;;
  file)
    selected_path=$(choose_file)
    [[ -n $selected_path ]] && share_path "$selected_path"
    ;;
  folder)
    selected_path=$(choose_folder)
    [[ -n $selected_path ]] && share_path "$selected_path"
    ;;
  receive)
    "$open_command" "$airdrop_app"
    ;;
  path)
    [[ -n ${2:-} ]] || { print -u2 "Usage: omacos share path FILE_OR_FOLDER"; exit 1; }
    share_path "$2"
    ;;
  *) print -u2 "Usage: omacos share <clipboard|file|folder|receive|path TARGET>"; exit 1 ;;
esac
