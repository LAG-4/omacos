#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
open_binary=${OMACOS_OPEN_BINARY:-/usr/bin/open}
action=${1:-}

default_value() {
  "$project_root/scripts/defaults.zsh" get "$1"
}

open_application() {
  "$open_binary" -a "$1" "${@:2}"
}

case $action in
  terminal)
    case $(default_value terminal) in
      ghostty) "$open_binary" -na Ghostty ;;
      terminal) "$open_binary" -na Terminal ;;
      iterm2) "$open_binary" -na iTerm ;;
    esac
    ;;
  tmux)
    terminal=$(default_value terminal)
    if [[ $terminal == "ghostty" ]]; then
      "$open_binary" -na Ghostty --args -e /bin/zsh -lc "tmux -f '$project_root/config/tmux/tmux.conf' new-session -A -s main"
    else
      "$open_binary" -na Terminal
    fi
    ;;
  browser)
    target=${2:-}
    case $(default_value browser) in
      system)
        if [[ -n $target ]]; then
          "$open_binary" "$target"
        else
          "$open_binary" -a Safari
        fi
        ;;
      safari) open_application Safari ${target:+"$target"} ;;
      chrome) open_application "Google Chrome" ${target:+"$target"} ;;
      brave) open_application "Brave Browser" ${target:+"$target"} ;;
      firefox) open_application Firefox ${target:+"$target"} ;;
      helium) open_application Helium ${target:+"$target"} ;;
    esac
    ;;
  browser-private)
    case $(default_value browser) in
      chrome) "$open_binary" -na "Google Chrome" --args --incognito ;;
      brave) "$open_binary" -na "Brave Browser" --args --incognito ;;
      firefox) "$open_binary" -na Firefox --args --private-window ;;
      helium) "$open_binary" -na Helium --args --incognito ;;
      *) "$open_binary" -a Safari ;;
    esac
    ;;
  editor)
    target=${2:-$PWD}
    case $(default_value editor) in
      nvim)
        target_escaped=$(printf %q "$target")
        "$open_binary" -na Ghostty --args -e /bin/zsh -lc "NVIM_APPNAME=omacos/nvim nvim $target_escaped"
        ;;
      vscode) open_application "Visual Studio Code" "$target" ;;
      cursor) open_application Cursor "$target" ;;
      zed) open_application Zed "$target" ;;
      sublime) open_application "Sublime Text" "$target" ;;
    esac
    ;;
  files)
    "$open_binary" "${2:-$PWD}"
    ;;
  webapp)
    if [[ -z ${2:-} ]]; then
      print -u2 "Usage: omacos launch webapp URL"
      exit 1
    fi
    "$project_root/scripts/launch.zsh" browser "$2"
    ;;
  *)
    print -u2 "Usage: omacos launch <terminal|tmux|browser|browser-private|editor|files|webapp> [TARGET]"
    exit 1
    ;;
esac
