#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
test_mode=${OMACOS_TEST_MODE:-false}
state_directory="$omacos_home/.local/state/omacos/toggles"
launch_agent="$omacos_home/Library/LaunchAgents/dev.omacos.stay-awake.plist"
shell_binary="$omacos_home/.local/bin/omacos-shell"
mkdir -p "$state_directory" "${launch_agent:h}"

normalize_toggle() {
  case $1 in
    idle|stay-awake) print 'stay-awake' ;;
    notification-silencing|notifications|dnd) print 'notification-silencing' ;;
    nightlight|night-light) print 'night-light' ;;
    bar|menu-bar) print 'bar-hidden' ;;
    *) print -r -- "$1" ;;
  esac
}

is_enabled() {
  [[ -f $state_directory/$1.enabled ]]
}

install_stay_awake_agent() {
  cat > "$launch_agent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>dev.omacos.stay-awake</string>
  <key>ProgramArguments</key><array><string>/usr/bin/caffeinate</string><string>-dimsu</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
</dict></plist>
EOF
  if ! $test_mode; then
    launchctl bootout "gui/$UID" "$launch_agent" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$UID" "$launch_agent"
  fi
}

remove_stay_awake_agent() {
  if ! $test_mode; then
    launchctl bootout "gui/$UID" "$launch_agent" >/dev/null 2>&1 || true
  fi
  rm -f "$launch_agent"
}

set_toggle() {
  local toggle=$1
  local enabled=$2
  if $enabled; then
    touch "$state_directory/$toggle.enabled"
  else
    rm -f "$state_directory/$toggle.enabled"
  fi

  case $toggle in
    stay-awake)
      if $enabled; then install_stay_awake_agent; else remove_stay_awake_agent; fi
      ;;
    bar-hidden)
      if [[ -x $shell_binary ]]; then "$shell_binary" --set-bar-hidden "$enabled"; fi
      ;;
  esac
}

toggle_value() {
  local toggle=$1
  if is_enabled "$toggle"; then
    set_toggle "$toggle" false
    print "$toggle disabled"
  else
    set_toggle "$toggle" true
    print "$toggle enabled"
  fi
}

case ${1:-list} in
  list)
    for name in stay-awake notification-silencing night-light bar-hidden; do
      if is_enabled "$name"; then value=true; else value=false; fi
      print "$name\t$value"
    done
    ;;
  status)
    toggle=$(normalize_toggle "${2:-}")
    [[ -n $toggle ]] || { print -u2 'Usage: omacos toggle status NAME'; exit 1; }
    if is_enabled "$toggle"; then value=true; else value=false; fi
    jq -nc --arg name "$toggle" --argjson enabled "$value" '{name:$name,enabled:$enabled}'
    ;;
  enable|disable|toggle)
    action=$1
    toggle=$(normalize_toggle "${2:-}")
    case $toggle in
      stay-awake|notification-silencing|night-light|bar-hidden) ;;
      *) print -u2 "Unknown toggle: $toggle"; exit 1 ;;
    esac
    case $action in
      enable) set_toggle "$toggle" true ;;
      disable) set_toggle "$toggle" false ;;
      toggle) toggle_value "$toggle" ;;
    esac
    ;;
  screensaver)
    if $test_mode; then
      print 'screensaver requested'
    else
      open -a ScreenSaverEngine
    fi
    ;;
  lock)
    if $test_mode; then
      print 'lock requested'
    else
      /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
    fi
    ;;
  sleep)
    if $test_mode; then
      print 'sleep requested'
    else
      /usr/bin/pmset sleepnow
    fi
    ;;
  *)
    print -u2 'Usage: omacos toggle <list|status NAME|enable NAME|disable NAME|toggle NAME|screensaver|lock|sleep>'
    exit 1
    ;;
esac
