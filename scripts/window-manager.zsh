#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
omacos_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
test_mode=${OMACOS_TEST_MODE:-false}
state_directory="$omacos_home/.local/state/omacos/window-manager"
profile_file="$omacos_home/.config/omacos/window-manager-profile"
backup_directory="$state_directory/backups"
aerospace_command=${OMACOS_AEROSPACE:-aerospace}
rift_command=${OMACOS_RIFT:-rift}
rift_cli_command=${OMACOS_RIFT_CLI:-rift-cli}
yabai_command=${OMACOS_YABAI:-yabai}
brew_command=${OMACOS_BREW:-brew}

current_profile() {
  if [[ -s $profile_file ]]; then
    local configured_profile
    configured_profile=$(<"$profile_file")
    case $configured_profile in
      aerospace|rift|yabai) print -r -- "$configured_profile" ;;
      *) print "aerospace" ;;
    esac
  else
    print "aerospace"
  fi
}

require_argument() {
  local value=${1:-}
  local usage=$2
  if [[ -z $value ]]; then
    print -u2 "Usage: $usage"
    return 1
  fi
}

direction_for_yabai() {
  case $1 in
    left) print "west" ;;
    right) print "east" ;;
    up) print "north" ;;
    down) print "south" ;;
    *) print -u2 "Unknown direction: $1"; return 1 ;;
  esac
}

record_optional_config_backup() {
  local profile=$1
  local target=$2
  local marker="$state_directory/$profile-backup-recorded"
  local had_marker="$state_directory/had-$profile-config"

  mkdir -p "$backup_directory"
  if [[ ! -f $marker ]]; then
    if [[ -f $target ]]; then
      cp "$target" "$backup_directory/$profile-config"
      touch "$had_marker"
    fi
    touch "$marker"
  fi
}

install_profile() {
  local profile=$1
  local target

  case $profile in
    aerospace)
      target="$omacos_home/.config/aerospace/aerospace.toml"
      mkdir -p "${target:h}"
      cp "$omacos_root/config/aerospace/aerospace.toml" "$target"
      ;;
    rift)
      if ! $test_mode && ! command -v "$rift_command" >/dev/null 2>&1; then
        "$brew_command" install acsandmann/tap/rift
      fi
      target="$omacos_home/.config/rift/config.toml"
      record_optional_config_backup rift "$target"
      mkdir -p "${target:h}"
      cp "$omacos_root/config/rift/config.toml" "$target"
      ;;
    yabai)
      if ! $test_mode && ! command -v "$yabai_command" >/dev/null 2>&1; then
        "$brew_command" install asmvik/formulae/yabai
      fi
      target="$omacos_home/.config/yabai/yabairc"
      record_optional_config_backup yabai "$target"
      mkdir -p "${target:h}"
      cp "$omacos_root/config/yabai/yabairc" "$target"
      chmod +x "$target"
      ;;
    *)
      print -u2 "Unknown window-manager profile: $profile"
      return 1
      ;;
  esac
}

stop_profile() {
  case $1 in
    aerospace)
      if ! $test_mode; then
        osascript -e 'tell application "AeroSpace" to quit' >/dev/null 2>&1 || true
      fi
      ;;
    rift)
      if command -v "$rift_command" >/dev/null 2>&1; then
        "$rift_command" service stop >/dev/null 2>&1 || true
      fi
      ;;
    yabai)
      if command -v "$yabai_command" >/dev/null 2>&1; then
        "$yabai_command" --stop-service >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

start_profile() {
  case $1 in
    aerospace)
      if ! $test_mode; then
        open -a AeroSpace
      elif command -v "$aerospace_command" >/dev/null 2>&1; then
        "$aerospace_command" reload-config >/dev/null 2>&1 || true
      fi
      ;;
    rift)
      "$rift_command" service install >/dev/null 2>&1 || true
      "$rift_command" service start
      ;;
    yabai)
      "$yabai_command" --start-service
      ;;
  esac
}

select_profile() {
  local requested_profile=$1
  case $requested_profile in
    aerospace|rift|yabai) ;;
    *) print -u2 "Usage: omacos wm profile <aerospace|rift|yabai>"; return 1 ;;
  esac

  local previous_profile
  previous_profile=$(current_profile)
  install_profile "$requested_profile"
  mkdir -p "${profile_file:h}"
  print -r -- "$requested_profile" > "$profile_file"

  if [[ $previous_profile != $requested_profile ]]; then
    stop_profile "$previous_profile"
  fi
  start_profile "$requested_profile"

  print "Window manager: $requested_profile"
  case $requested_profile in
    aerospace) print "AeroSpace is the supported SIP-on default." ;;
    rift) print "Rift is experimental and keeps SIP enabled. Approve Accessibility if macOS asks." ;;
    yabai) print "yabai is running in SIP-on mode. Power-only features stay disabled." ;;
  esac
}

restore_optional_configs() {
  local profile target
  for profile in rift yabai; do
    if [[ $profile == "rift" ]]; then
      target="$omacos_home/.config/rift/config.toml"
    else
      target="$omacos_home/.config/yabai/yabairc"
    fi

    if [[ -f $state_directory/had-$profile-config ]]; then
      mkdir -p "${target:h}"
      cp "$backup_directory/$profile-config" "$target"
    elif [[ -f $state_directory/$profile-backup-recorded ]]; then
      rm -f "$target"
    fi
  done
}

print_status() {
  local profile
  profile=$(current_profile)
  print "profile=$profile"
  case $profile in
    aerospace)
      command -v "$aerospace_command" >/dev/null 2>&1 && print "command=available" || print "command=missing"
      ;;
    rift)
      command -v "$rift_cli_command" >/dev/null 2>&1 && print "command=available" || print "command=missing"
      ;;
    yabai)
      command -v "$yabai_command" >/dev/null 2>&1 && print "command=available" || print "command=missing"
      ;;
  esac
  print "sip=$(csrutil status 2>/dev/null || print unknown)"
}

run_aerospace_action() {
  local action=$1
  shift
  case $action in
    close) "$aerospace_command" close ;;
    toggle-floating) "$aerospace_command" layout floating tiling ;;
    toggle-fullscreen) "$aerospace_command" fullscreen ;;
    toggle-split) "$aerospace_command" layout tiles horizontal vertical ;;
    toggle-workspace-layout) "$aerospace_command" layout tiles accordion ;;
    scratchpad-toggle) "$aerospace_command" summon-workspace scratchpad ;;
    scratchpad-move) "$aerospace_command" move-node-to-workspace scratchpad ;;
    workspace-current) "$aerospace_command" list-workspaces --focused ;;
    workspace-focus) "$aerospace_command" workspace "$1" ;;
    workspace-move) "$aerospace_command" move-node-to-workspace "$1" ;;
    workspace-back) "$aerospace_command" workspace-back-and-forth ;;
    workspace-next-monitor) "$aerospace_command" move-workspace-to-monitor --wrap-around next ;;
    resize-grow) "$aerospace_command" resize smart +50 ;;
    resize-shrink) "$aerospace_command" resize smart -50 ;;
    focus) "$aerospace_command" focus "$1" ;;
    move) "$aerospace_command" move "$1" ;;
    join) "$aerospace_command" join-with "$1" ;;
    *) print -u2 "Unknown window-manager action: $action"; return 1 ;;
  esac
}

rift_active_layout() {
  "$rift_cli_command" query workspace-layout | jq -r 'first(.[] | select(.is_active) | .layout_mode)'
}

run_rift_action() {
  local action=$1
  shift
  case $action in
    close) "$rift_cli_command" execute window close ;;
    toggle-floating) "$rift_cli_command" execute window toggle-float ;;
    toggle-fullscreen) "$rift_cli_command" execute window toggle-fullscreen ;;
    toggle-split) "$rift_cli_command" execute layout toggle-orientation ;;
    toggle-workspace-layout)
      if [[ $(rift_active_layout) == "stack" ]]; then
        "$rift_cli_command" execute workspace set-layout traditional
      else
        "$rift_cli_command" execute workspace set-layout stack
      fi
      ;;
    scratchpad-toggle)
      if [[ $("$rift_cli_command" query workspaces | jq -r 'first(.[] | select(.is_active) | .index)') == "11" ]]; then
        "$rift_cli_command" execute workspace last
      else
        "$rift_cli_command" execute workspace switch 11
      fi
      ;;
    scratchpad-move) "$rift_cli_command" execute workspace move-window 11 ;;
    workspace-current) "$rift_cli_command" query workspaces | jq -r 'first(.[] | select(.is_active) | .index)' ;;
    workspace-focus) "$rift_cli_command" execute workspace switch "$1" ;;
    workspace-move) "$rift_cli_command" execute workspace move-window "$1" ;;
    workspace-back) "$rift_cli_command" execute workspace last ;;
    workspace-next-monitor) "$rift_cli_command" execute display move-window --direction right ;;
    resize-grow) "$rift_cli_command" execute window resize-grow --orientation smart ;;
    resize-shrink) "$rift_cli_command" execute window resize-shrink --orientation smart ;;
    focus) "$rift_cli_command" execute window focus "$1" ;;
    move) "$rift_cli_command" execute layout move-node "$1" ;;
    join) "$rift_cli_command" execute layout join-window "$1" ;;
    *) print -u2 "Unknown window-manager action: $action"; return 1 ;;
  esac
}

yabai_active_layout() {
  "$yabai_command" -m query --spaces --space | jq -r '.type'
}

run_yabai_action() {
  local action=$1
  shift
  local direction
  case $action in
    close) "$yabai_command" -m window --close ;;
    toggle-floating) "$yabai_command" -m window --toggle float ;;
    toggle-fullscreen) "$yabai_command" -m window --toggle zoom-fullscreen ;;
    toggle-split) "$yabai_command" -m window --toggle split ;;
    toggle-workspace-layout)
      if [[ $(yabai_active_layout) == "stack" ]]; then
        "$yabai_command" -m space --layout bsp
      else
        "$yabai_command" -m space --layout stack
      fi
      ;;
    scratchpad-toggle) "$yabai_command" -m window --toggle omacos-scratchpad ;;
    scratchpad-move) "$yabai_command" -m window --scratchpad omacos-scratchpad ;;
    workspace-current) "$yabai_command" -m query --spaces --space | jq -r '.index' ;;
    workspace-focus) "$yabai_command" -m space --focus "$1" ;;
    workspace-move) "$yabai_command" -m window --space "$1" ;;
    workspace-back) "$yabai_command" -m space --focus recent ;;
    workspace-next-monitor) "$yabai_command" -m space --display next ;;
    resize-grow) "$yabai_command" -m window --ratio rel:0.05 ;;
    resize-shrink) "$yabai_command" -m window --ratio rel:-0.05 ;;
    focus)
      direction=$(direction_for_yabai "$1")
      "$yabai_command" -m window --focus "$direction"
      ;;
    move|join)
      direction=$(direction_for_yabai "$1")
      "$yabai_command" -m window --warp "$direction"
      ;;
    *) print -u2 "Unknown window-manager action: $action"; return 1 ;;
  esac
}

run_action() {
  local action=${1:-}
  shift || true
  require_argument "$action" "omacos wm ACTION" || return 1
  case $action in
    workspace-focus|workspace-move|focus|move|join)
      require_argument "${1:-}" "omacos wm $action VALUE" || return 1
      ;;
  esac
  case $(current_profile) in
    aerospace) run_aerospace_action "$action" "$@" ;;
    rift) run_rift_action "$action" "$@" ;;
    yabai) run_yabai_action "$action" "$@" ;;
  esac
}

print_power_mode_guide() {
  cat <<'EOF'
OMacOS never changes System Integrity Protection or sudoers.

The yabai scripting addition can add scratchpads, opacity, sticky windows, and
native Space control, but Apple Silicon requires reducing SIP protections from
macOS Recovery. Read the upstream instructions and decide whether that security
tradeoff is acceptable:

  https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection
  https://github.com/asmvik/yabai/wiki/Installing-yabai-(latest-release)#configure-scripting-addition

After completing those manual steps, run `sudo yabai --load-sa`. OMacOS will
then route its power-only yabai shortcuts through the already-loaded addition.
EOF
}

case ${1:-status} in
  init)
    install_profile aerospace
    mkdir -p "${profile_file:h}"
    [[ -s $profile_file ]] || print "aerospace" > "$profile_file"
    ;;
  profile)
    if [[ -z ${2:-} ]]; then
      current_profile
    else
      select_profile "$2"
    fi
    ;;
  install)
    require_argument "${2:-}" "omacos wm install <aerospace|rift|yabai>"
    install_profile "$2"
    ;;
  status|doctor)
    print_status
    ;;
  power-mode)
    case ${2:-guide} in
      guide) print_power_mode_guide ;;
      status)
        print_status
        if [[ $(current_profile) != "yabai" ]]; then
          print "power-features=inactive (select the yabai profile first)"
        elif "$yabai_command" -m query --spaces --space >/dev/null 2>&1; then
          print "power-features=availability depends on the manually loaded scripting addition"
        else
          print "power-features=unavailable"
        fi
        ;;
      *) print -u2 "Usage: omacos wm power-mode <guide|status>"; exit 1 ;;
    esac
    ;;
  restore)
    stop_profile "$(current_profile)"
    restore_optional_configs
    ;;
  close|toggle-floating|toggle-fullscreen|toggle-split|toggle-workspace-layout|scratchpad-toggle|scratchpad-move|workspace-current|workspace-focus|workspace-move|workspace-back|workspace-next-monitor|resize-grow|resize-shrink|focus|move|join)
    run_action "$@"
    ;;
  *)
    print -u2 "Usage: omacos wm <profile|status|install|power-mode|ACTION>"
    exit 1
    ;;
esac
