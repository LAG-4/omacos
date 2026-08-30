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
shell_binary=${OMACOS_SHELL_BINARY:-$omacos_home/.local/bin/omacos-shell}
[[ -x $shell_binary ]] || shell_binary="$omacos_root/.build/debug/omacos-shell"

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
    next) print "next" ;;
    prev|previous) print "prev" ;;
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

configured_bar_position() {
  local bar_configuration="$omacos_home/.config/omacos/bar.json"
  if [[ -f $bar_configuration ]]; then
    local position
    position=$(jq -r '.position // "top"' "$bar_configuration" 2>/dev/null || print top)
    [[ $position == "top" || $position == "bottom" || $position == "left" || $position == "right" ]] && print -r -- "$position" || print top
  else
    print top
  fi
}

persist_bar_position() {
  local position=$1
  local bar_configuration="$omacos_home/.config/omacos/bar.json"
  mkdir -p "${bar_configuration:h}"
  if [[ -f $bar_configuration ]]; then
    local temporary_configuration
    temporary_configuration=$(mktemp -t omacos-bar-configuration.XXXXXX)
    jq --arg position "$position" '.position = $position' "$bar_configuration" > "$temporary_configuration"
    mv "$temporary_configuration" "$bar_configuration"
  else
    jq -nc --arg position "$position" '{position:$position,transparent:false}' > "$bar_configuration"
  fi
}

configured_window_gaps() {
  local gap_state="$omacos_home/.config/omacos/window-gaps"
  if [[ -f $gap_state && $(<"$gap_state") == "false" ]]; then
    print false
  else
    print true
  fi
}

configured_window_transparency() {
  if [[ -f $state_directory/window-transparency-enabled ]]; then
    print true
  else
    print false
  fi
}

toggle_window_transparency() {
  if [[ $(current_profile) != "yabai" ]]; then
    print -u2 "Window transparency requires the optional yabai power mode."
    print -u2 "Select yabai with 'omacos wm profile yabai', then read 'omacos wm power-mode guide'."
    return 1
  fi

  mkdir -p "$state_directory"
  if [[ $(configured_window_transparency) == "true" ]]; then
    "$yabai_command" -m window --opacity 1.0
    rm -f "$state_directory/window-transparency-enabled"
    print "window-transparency=false"
  else
    "$yabai_command" -m window --opacity 0.78
    touch "$state_directory/window-transparency-enabled"
    print "window-transparency=true"
  fi
}

set_rift_layout_gaps() {
  local target=$1
  local top_gap=$2
  local bottom_gap=$3
  local left_gap=$4
  local right_gap=$5
  local spacing=$6
  local temporary_config
  temporary_config=$(mktemp -t omacos-rift-gaps.XXXXXX)
  awk -v top_gap="$top_gap.0" -v bottom_gap="$bottom_gap.0" -v left_gap="$left_gap.0" -v right_gap="$right_gap.0" -v spacing="$spacing.0" '
    /^\[settings\.layout\.gaps\.outer\]$/ { in_outer=1; in_inner=0; print; next }
    /^\[settings\.layout\.gaps\.inner\]$/ { in_outer=0; in_inner=1; print; next }
    /^\[/ { in_outer=0; in_inner=0 }
    in_outer && /^top = / { print "top = " top_gap; next }
    in_outer && /^bottom = / { print "bottom = " bottom_gap; next }
    in_outer && /^left = / { print "left = " left_gap; next }
    in_outer && /^right = / { print "right = " right_gap; next }
    in_inner && /^(horizontal|vertical) = / { split($0, parts, " = "); print parts[1] " = " spacing; next }
    { print }
  ' "$target" > "$temporary_config"
  mv "$temporary_config" "$target"
}

set_profile_bar_position() {
  local profile=$1
  local position=$2
  local spacing=8
  local reserved_gap=42
  if [[ $position == "left" || $position == "right" ]]; then
    reserved_gap=56
  fi
  if [[ $(configured_window_gaps) == "false" ]]; then
    spacing=0
    if [[ $position == "left" || $position == "right" ]]; then
      reserved_gap=48
    else
      reserved_gap=34
    fi
  fi
  local top_gap=$spacing
  local bottom_gap=$spacing
  local left_gap=$spacing
  local right_gap=$spacing
  case $position in
    # macOS window managers already tile below the native menu-bar safe area.
    # The OMacOS top bar replaces that visible area, so only the normal window gap remains.
    top) top_gap=$spacing ;;
    bottom) bottom_gap=$reserved_gap ;;
    left) left_gap=$reserved_gap ;;
    right) right_gap=$reserved_gap ;;
  esac

  case $profile in
    aerospace)
      local aerospace_config="$omacos_home/.config/aerospace/aerospace.toml"
      if [[ -f $aerospace_config ]]; then
        /usr/bin/sed -i '' -E "s/^gaps\\.inner\\.horizontal = .*/gaps.inner.horizontal = $spacing/" "$aerospace_config"
        /usr/bin/sed -i '' -E "s/^gaps\\.inner\\.vertical = .*/gaps.inner.vertical = $spacing/" "$aerospace_config"
        /usr/bin/sed -i '' -E "s/^gaps\\.outer\\.left = .*/gaps.outer.left = $left_gap/" "$aerospace_config"
        /usr/bin/sed -i '' -E "s/^gaps\\.outer\\.right = .*/gaps.outer.right = $right_gap/" "$aerospace_config"
        /usr/bin/sed -i '' -E "s/^gaps\\.outer\\.top = .*/gaps.outer.top = $top_gap/" "$aerospace_config"
        /usr/bin/sed -i '' -E "s/^gaps\\.outer\\.bottom = .*/gaps.outer.bottom = $bottom_gap/" "$aerospace_config"
      fi
      ;;
    rift)
      local rift_config="$omacos_home/.config/rift/config.toml"
      [[ -f $rift_config ]] && set_rift_layout_gaps "$rift_config" "$top_gap" "$bottom_gap" "$left_gap" "$right_gap" "$spacing"
      ;;
    yabai)
      local yabai_config="$omacos_home/.config/yabai/yabairc"
      if [[ -f $yabai_config ]]; then
        /usr/bin/sed -i '' -E "s/^yabai -m config left_padding .*/yabai -m config left_padding $left_gap/" "$yabai_config"
        /usr/bin/sed -i '' -E "s/^yabai -m config right_padding .*/yabai -m config right_padding $right_gap/" "$yabai_config"
        /usr/bin/sed -i '' -E "s/^yabai -m config window_gap .*/yabai -m config window_gap $spacing/" "$yabai_config"
        /usr/bin/sed -i '' -E "s/^yabai -m config top_padding .*/yabai -m config top_padding $top_gap/" "$yabai_config"
        /usr/bin/sed -i '' -E "s/^yabai -m config bottom_padding .*/yabai -m config bottom_padding $bottom_gap/" "$yabai_config"
      fi
      ;;
  esac
}

apply_bar_position() {
  local position=$1
  [[ $position == "top" || $position == "bottom" || $position == "left" || $position == "right" ]] || {
    print -u2 'Bar position must be top, bottom, left, or right.'
    return 1
  }
  local profile
  for profile in aerospace rift yabai; do
    set_profile_bar_position "$profile" "$position"
  done
  case $(current_profile) in
    aerospace) "$aerospace_command" reload-config >/dev/null 2>&1 || true ;;
    rift) : ;;
    yabai)
      local spacing=8
      local reserved_gap=42
      if [[ $position == "left" || $position == "right" ]]; then reserved_gap=56; fi
      if [[ $(configured_window_gaps) == "false" ]]; then
        spacing=0
        if [[ $position == "left" || $position == "right" ]]; then reserved_gap=48; else reserved_gap=34; fi
      fi
      local top_gap=$spacing
      local bottom_gap=$spacing
      local left_gap=$spacing
      local right_gap=$spacing
      case $position in
        top) top_gap=$spacing ;;
        bottom) bottom_gap=$reserved_gap ;;
        left) left_gap=$reserved_gap ;;
        right) right_gap=$reserved_gap ;;
      esac
      "$yabai_command" -m config top_padding "$top_gap"
      "$yabai_command" -m config bottom_padding "$bottom_gap"
      "$yabai_command" -m config left_padding "$left_gap"
      "$yabai_command" -m config right_padding "$right_gap"
      "$yabai_command" -m config window_gap "$spacing"
      ;;
  esac
}

apply_window_gaps() {
  local enabled=$1
  [[ $enabled == "true" || $enabled == "false" ]] || {
    print -u2 'Window gaps must be true or false.'
    return 1
  }
  mkdir -p "$omacos_home/.config/omacos"
  print -r -- "$enabled" > "$omacos_home/.config/omacos/window-gaps"
  apply_bar_position "$(configured_bar_position)"
}

install_profile() {
  local profile=$1
  local target

  case $profile in
    aerospace)
      target="$omacos_home/.config/aerospace/aerospace.toml"
      mkdir -p "${target:h}"
      cp "$omacos_root/config/aerospace/aerospace.toml" "$target"
      set_profile_bar_position aerospace "$(configured_bar_position)"
      ;;
    rift)
      if ! $test_mode && ! command -v "$rift_command" >/dev/null 2>&1; then
        "$brew_command" install acsandmann/tap/rift
      fi
      target="$omacos_home/.config/rift/config.toml"
      record_optional_config_backup rift "$target"
      mkdir -p "${target:h}"
      cp "$omacos_root/config/rift/config.toml" "$target"
      set_profile_bar_position rift "$(configured_bar_position)"
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
      set_profile_bar_position yabai "$(configured_bar_position)"
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
    workspace-move) "$aerospace_command" move-node-to-workspace --focus-follows-window "$1" ;;
    workspace-move-silent) "$aerospace_command" move-node-to-workspace "$1" ;;
    workspace-next) "$aerospace_command" workspace --wrap-around next ;;
    workspace-previous) "$aerospace_command" workspace --wrap-around prev ;;
    workspace-back) "$aerospace_command" workspace-back-and-forth ;;
    workspace-next-monitor) "$aerospace_command" move-workspace-to-monitor --wrap-around next ;;
    workspace-move-monitor) "$aerospace_command" move-workspace-to-monitor --wrap-around "$1" ;;
    monitor-focus) "$aerospace_command" focus-monitor --wrap-around "$1" ;;
    focus-cycle) "$aerospace_command" focus --wrap-around "dfs-$1" ;;
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
    workspace-move)
      "$rift_cli_command" execute workspace move-window "$1"
      "$rift_cli_command" execute workspace switch "$1"
      ;;
    workspace-move-silent) "$rift_cli_command" execute workspace move-window "$1" ;;
    workspace-next) "$rift_cli_command" execute workspace next ;;
    workspace-previous) "$rift_cli_command" execute workspace previous ;;
    workspace-back) "$rift_cli_command" execute workspace last ;;
    workspace-next-monitor) "$rift_cli_command" execute display move-window --direction right ;;
    workspace-move-monitor) "$rift_cli_command" execute display move-window --direction "$1" ;;
    monitor-focus) "$rift_cli_command" execute display focus --direction "$1" ;;
    focus-cycle) "$rift_cli_command" execute window "focus-$1" ;;
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
    workspace-move)
      "$yabai_command" -m window --space "$1"
      "$yabai_command" -m space --focus "$1"
      ;;
    workspace-move-silent) "$yabai_command" -m window --space "$1" ;;
    workspace-next) "$yabai_command" -m space --focus next ;;
    workspace-previous) "$yabai_command" -m space --focus prev ;;
    workspace-back) "$yabai_command" -m space --focus recent ;;
    workspace-next-monitor) "$yabai_command" -m space --display next ;;
    workspace-move-monitor)
      direction=$(direction_for_yabai "$1")
      "$yabai_command" -m space --display "$direction"
      ;;
    monitor-focus)
      direction=$(direction_for_yabai "$1")
      "$yabai_command" -m display --focus "$direction"
      ;;
    focus-cycle) "$yabai_command" -m window --focus "$1" ;;
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
  local post_action=''
  shift || true
  require_argument "$action" "omacos wm ACTION" || return 1
  case $action in
    close-all) "$shell_binary" --close-all-windows; return ;;
    window-width-save) "$shell_binary" --window-width save; return ;;
    window-width-restore) "$shell_binary" --window-width restore; return ;;
    full-width-toggle) "$shell_binary" --window-full-width; return ;;
    square-aspect-toggle) "$shell_binary" --window-square-aspect; return ;;
    tiled-fullscreen) action=toggle-fullscreen ;;
    pop-window) action=toggle-floating ;;
    pseudo-toggle) action=toggle-floating; post_action=pseudo ;;
    transparency-toggle) toggle_window_transparency; return ;;
  esac
  case $action in
    workspace-focus|workspace-move|workspace-move-silent|workspace-move-monitor|monitor-focus|focus-cycle|move|join)
      require_argument "${1:-}" "omacos wm $action VALUE" || return 1
      ;;
  esac
  case $(current_profile) in
    aerospace) run_aerospace_action "$action" "$@" ;;
    rift) run_rift_action "$action" "$@" ;;
    yabai) run_yabai_action "$action" "$@" ;;
  esac
  if [[ $post_action == "pseudo" ]]; then
    "$shell_binary" --window-pseudo
  fi
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
  bar-position)
    require_argument "${2:-}" "omacos wm bar-position <top|bottom|left|right>"
    [[ $2 == "top" || $2 == "bottom" || $2 == "left" || $2 == "right" ]] || {
      print -u2 'Bar position must be top, bottom, left, or right.'
      exit 1
    }
    persist_bar_position "$2"
    apply_bar_position "$2"
    ;;
  gaps)
    case ${2:-status} in
      status) print "window-gaps=$(configured_window_gaps)" ;;
      enable) apply_window_gaps true ;;
      disable) apply_window_gaps false ;;
      toggle)
        if [[ $(configured_window_gaps) == "true" ]]; then
          apply_window_gaps false
        else
          apply_window_gaps true
        fi
        ;;
      *) print -u2 'Usage: omacos wm gaps <status|enable|disable|toggle>'; exit 1 ;;
    esac
    ;;
  transparency)
    case ${2:-status} in
      status) print "window-transparency=$(configured_window_transparency)" ;;
      toggle) toggle_window_transparency ;;
      *) print -u2 'Usage: omacos wm transparency <status|toggle>'; exit 1 ;;
    esac
    ;;
  restore)
    stop_profile "$(current_profile)"
    restore_optional_configs
    ;;
  close|close-all|window-width-save|window-width-restore|full-width-toggle|square-aspect-toggle|tiled-fullscreen|pop-window|pseudo-toggle|transparency-toggle|toggle-floating|toggle-fullscreen|toggle-split|toggle-workspace-layout|scratchpad-toggle|scratchpad-move|workspace-current|workspace-focus|workspace-move|workspace-move-silent|workspace-next|workspace-previous|workspace-back|workspace-next-monitor|workspace-move-monitor|monitor-focus|focus-cycle|resize-grow|resize-shrink|focus|move|join)
    run_action "$@"
    ;;
  *)
    print -u2 "Usage: omacos wm <profile|status|install|power-mode|bar-position|gaps|transparency|ACTION>"
    exit 1
    ;;
esac
