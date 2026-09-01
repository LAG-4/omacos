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
      # A plain new app instance is the reliable macOS launch path. Passing a
      # Linux-style command option caused Super+Enter to fail on current Ghostty.
      ghostty) "$open_binary" -na Ghostty.app ;;
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
  herdr)
    if ! command -v herdr >/dev/null 2>&1; then
      print -u2 "Herdr is not installed. Install it before using this shortcut."
      exit 1
    fi
    "$open_binary" -na Ghostty --args -e /bin/zsh -lc herdr
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
  files-cwd)
    focused_directory=$("$project_root/scripts/focused-directory.zsh")
    "$open_binary" "$focused_directory"
    ;;
  webapp)
    if [[ -z ${2:-} ]]; then
      print -u2 "Usage: omacos launch webapp URL"
      exit 1
    fi
    "$project_root/scripts/launch.zsh" browser "$2"
    ;;
  app)
    case ${2:-} in
      music) open_application Music ;;
      spotify) open_application Spotify ;;
      signal) open_application Signal ;;
      obsidian) open_application Obsidian ;;
      passwords) open_application "1Password" ;;
      docker) open_application Docker ;;
      omawrite) open_application TextEdit ;;
      calculator) open_application Calculator ;;
      *) print -u2 "Unknown application shortcut: ${2:-}"; exit 1 ;;
    esac
    ;;
  web)
    case ${2:-} in
      chatgpt) url="https://chatgpt.com" ;;
      grok) url="https://grok.com" ;;
      calendar) url="https://app.hey.com/calendar/weeks/" ;;
      email) url="https://app.hey.com" ;;
      email-new) url="https://app.hey.com/messages/new?display=standalone&new_window=true" ;;
      youtube) url="https://youtube.com/" ;;
      whatsapp) url="https://web.whatsapp.com/" ;;
      messages) url="https://messages.google.com/web/conversations" ;;
      photos) url="https://photos.google.com/" ;;
      maps) url="https://maps.google.com/" ;;
      x) url="https://x.com/" ;;
      x-post) url="https://x.com/compose/post" ;;
      *) print -u2 "Unknown web shortcut: ${2:-}"; exit 1 ;;
    esac
    "$project_root/scripts/launch.zsh" browser "$url"
    ;;
  docs)
    case ${2:-} in
      tmux) url="https://github.com/tmux/tmux/wiki/Getting-Started" ;;
      herdr) url="https://github.com/LAG-4/herdr" ;;
      *) print -u2 "Unknown documentation shortcut: ${2:-}"; exit 1 ;;
    esac
    "$project_root/scripts/launch.zsh" browser "$url"
    ;;
  *)
    print -u2 "Usage: omacos launch <terminal|tmux|herdr|browser|browser-private|editor|files|files-cwd|webapp|app|web|docs> [TARGET]"
    exit 1
    ;;
esac
