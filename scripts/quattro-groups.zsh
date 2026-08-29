#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
omacos_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
shell_binary=${OMACOS_SHELL_BINARY:-$omacos_home/.local/bin/omacos-shell}
open_command=${OMACOS_OPEN_BINARY:-/usr/bin/open}
osascript_command=${OMACOS_OSASCRIPT:-/usr/bin/osascript}
pmset_command=${OMACOS_PMSET:-/usr/bin/pmset}
blueutil_command=${OMACOS_BLUEUTIL:-blueutil}
group=${1:-}
action=${2:-show}

show_panel() {
  local panel=$1
  [[ -x $shell_binary ]] || {
    print -u2 "OMacOS shell is not installed at $shell_binary"
    return 1
  }
  "$shell_binary" --toggle-panel "$panel"
}

show_menu() {
  local menu_id=$1
  [[ -x $shell_binary ]] || {
    print -u2 "OMacOS shell is not installed at $shell_binary"
    return 1
  }
  "$shell_binary" --toggle-menu "$menu_id"
}

case $group in
  audio)
    case $action in
      show|panel) show_panel audio ;;
      status) "$osascript_command" -e 'get volume settings' ;;
      volume)
        [[ ${3:-} == <-> ]] || { print -u2 'Usage: omacos audio volume 0..100'; exit 1; }
        (( $3 >= 0 && $3 <= 100 )) || { print -u2 'Audio volume must be between 0 and 100.'; exit 1; }
        "$osascript_command" -e "set volume output volume $3"
        ;;
      mute) "$osascript_command" -e 'set volume output muted true' ;;
      unmute) "$osascript_command" -e 'set volume output muted false' ;;
      settings) "$open_command" 'x-apple.systempreferences:com.apple.Sound-Settings.extension' ;;
      *) print -u2 'Usage: omacos audio <show|status|volume 0..100|mute|unmute|settings>'; exit 1 ;;
    esac
    ;;
  bar)
    case $action in
      show|enable) "$omacos_root/scripts/toggles.zsh" disable bar ;;
      hide|disable) "$omacos_root/scripts/toggles.zsh" enable bar ;;
      toggle) "$omacos_root/scripts/toggles.zsh" toggle bar ;;
      status) "$shell_binary" --bar-status ;;
      position)
        position=${3:-}
        [[ $position == "top" || $position == "bottom" ]] || { print -u2 'Usage: omacos bar position <top|bottom>'; exit 1; }
        "$shell_binary" --bar-position "$position"
        "$omacos_root/scripts/window-manager.zsh" bar-position "$position"
        print "OMacOS bar position: $position"
        ;;
      transparency)
        transparency_action=${3:-toggle}
        current_transparency=$("$shell_binary" --bar-status | jq -r '.transparent')
        case $transparency_action in
          enable) transparent=true ;;
          disable) transparent=false ;;
          toggle) [[ $current_transparency == "true" ]] && transparent=false || transparent=true ;;
          *) print -u2 'Usage: omacos bar transparency <toggle|enable|disable>'; exit 1 ;;
        esac
        "$shell_binary" --bar-transparency "$transparent"
        print "OMacOS bar transparency: $transparent"
        ;;
      *) print -u2 'Usage: omacos bar <show|hide|toggle|status|position top|bottom|transparency toggle|enable|disable>'; exit 1 ;;
    esac
    ;;
  battery)
    case $action in
      show|panel) show_panel notice-battery ;;
      status) "$pmset_command" -g batt ;;
      settings) "$open_command" 'x-apple.systempreferences:com.apple.Battery-Settings.extension' ;;
      *) print -u2 'Usage: omacos battery <show|status|settings>'; exit 1 ;;
    esac
    ;;
  bluetooth)
    case $action in
      show|panel) show_panel bluetooth ;;
      status) command -v "$blueutil_command" >/dev/null 2>&1 && "$blueutil_command" --power || print unknown ;;
      on) "$blueutil_command" --power 1 ;;
      off) "$blueutil_command" --power 0 ;;
      settings) "$open_command" 'x-apple.systempreferences:com.apple.BluetoothSettings' ;;
      *) print -u2 'Usage: omacos bluetooth <show|status|on|off|settings>'; exit 1 ;;
    esac
    ;;
  branding)
    case $action in
      show|status) print 'OMacOS — an independent Omarchy-inspired environment for macOS' ;;
      open) "$open_command" 'https://github.com/LAG-4/omacos' ;;
      *) print -u2 'Usage: omacos branding <show|open>'; exit 1 ;;
    esac
    ;;
  clipboard)
    clipboard_path="$omacos_home/.local/state/omacos/clipboard-history.json"
    case $action in
      show|panel) show_panel clipboard ;;
      list) [[ -f $clipboard_path ]] && jq -c '.entries // .' "$clipboard_path" || print '[]' ;;
      clear)
        mkdir -p "${clipboard_path:h}"
        print '[]' > "$clipboard_path"
        if [[ -x $shell_binary ]]; then
          "$shell_binary" --clipboard-clear
        fi
        print 'Clipboard history cleared.'
        ;;
      *) print -u2 'Usage: omacos clipboard <show|list|clear>'; exit 1 ;;
    esac
    ;;
  cmd)
    case $action in
      present) command -v "${3:-}" >/dev/null 2>&1 ;;
      missing) ! command -v "${3:-}" >/dev/null 2>&1 ;;
      path) command -v "${3:-}" ;;
      *) print -u2 'Usage: omacos cmd <present|missing|path> COMMAND'; exit 1 ;;
    esac
    ;;
  config)
    case $action in
      show|open) mkdir -p "$omacos_home/.config/omacos"; "$open_command" "$omacos_home/.config/omacos" ;;
      path) print -r -- "$omacos_home/.config/omacos" ;;
      *) print -u2 'Usage: omacos config <open|path>'; exit 1 ;;
    esac
    ;;
  debug)
    case $action in
      show|status) print "root=$omacos_root"; print "state=$omacos_home/.local/state/omacos" ;;
      permissions) "$omacos_root/scripts/permissions.zsh" status ;;
      hardware) "$omacos_root/scripts/qa.zsh" report ;;
      *) print -u2 'Usage: omacos debug <status|permissions|hardware>'; exit 1 ;;
    esac
    ;;
  dev)
    case $action in
      show|gallery) show_panel dev-gallery ;;
      status) print "OMacOS source: $omacos_root" ;;
      *) print -u2 'Usage: omacos dev <gallery|status>'; exit 1 ;;
    esac
    ;;
  disk)
    case $action in
      show|panel) show_panel disk-speedtest ;;
      speedtest|benchmark) "$omacos_root/scripts/speedtest.zsh" disk ;;
      status) /bin/df -h / ;;
      *) print -u2 'Usage: omacos disk <show|status|speedtest>'; exit 1 ;;
    esac
    ;;
  games)
    case $action in
      show|list) "$omacos_root/scripts/packages.zsh" list gaming ;;
      install|remove|status) "$omacos_root/scripts/packages.zsh" "$action" "${3:-}" "${4:-}" ;;
      *) print -u2 'Usage: omacos games <list|status ID|install ID [--yes]|remove ID [--yes]>'; exit 1 ;;
    esac
    ;;
  install)
    if [[ $action == "show" ]]; then
      show_panel packages
    else
      "$omacos_root/scripts/packages.zsh" install "$action" "${@:3}"
    fi
    ;;
  remove)
    if [[ $action == "show" ]]; then
      show_panel packages
    else
      "$omacos_root/scripts/packages.zsh" remove "$action" "${@:3}"
    fi
    ;;
  monitor)
    case $action in
      show|panel) show_panel display ;;
      settings) "$open_command" 'x-apple.systempreferences:com.apple.Displays-Settings.extension' ;;
      *) print -u2 'Usage: omacos monitor <show|settings>'; exit 1 ;;
    esac
    ;;
  power)
    case $action in
      show|panel) show_panel power ;;
      status) "$pmset_command" -g batt ;;
      settings) "$open_command" 'x-apple.systempreferences:com.apple.Battery-Settings.extension' ;;
      *) print -u2 'Usage: omacos power <show|status|settings>'; exit 1 ;;
    esac
    ;;
  setup)
    case $action in
      show|menu) show_menu setup ;;
      permissions) show_panel permissions ;;
      *) "$omacos_root/scripts/menu.zsh" run "setup.$action" ;;
    esac
    ;;
  snapshot)
    "$omacos_root/scripts/managed-snapshot.zsh" "${2:-list}" "${3:-}"
    ;;
  system)
    case $action in
      show|menu) show_panel system ;;
      lock|sleep) "$omacos_root/scripts/toggles.zsh" "$action" ;;
      *) print -u2 'Usage: omacos system <show|lock|sleep>'; exit 1 ;;
    esac
    ;;
  tailscale)
    "$omacos_root/scripts/services.zsh" tailscale "${2:-status}" "${@:3}"
    ;;
  wifi)
    "$omacos_root/scripts/network.zsh" "${2:-status}" "${@:3}"
    ;;
  *)
    print -u2 "Unknown Quattro compatibility group: $group"
    exit 1
    ;;
esac
