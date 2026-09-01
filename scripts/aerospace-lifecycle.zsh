#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
omacos_root=${OMACOS_ROOT:-${0:A:h:h}}
test_mode=${OMACOS_TEST_MODE:-false}
lifecycle_directory="$omacos_home/.local/state/omacos/aerospace-lifecycle"
login_state_file=${OMACOS_AEROSPACE_LOGIN_STATE_FILE:-}
process_state_file=${OMACOS_AEROSPACE_PROCESS_STATE_FILE:-}
open_command=${OMACOS_AEROSPACE_OPEN_COMMAND:-}
quit_command=${OMACOS_AEROSPACE_QUIT_COMMAND:-}
aerospace_command=${OMACOS_AEROSPACE:-aerospace}

current_aerospace_login_state() {
  if [[ -n $login_state_file && -f $login_state_file ]]; then
    cat "$login_state_file"
    return
  fi
  if $test_mode; then
    print disabled
    return
  fi

  local background_items
  background_items=$(/usr/bin/sfltool dumpbtm 2>/dev/null || true)
  local disposition
  disposition=$(print -r -- "$background_items" | /usr/bin/awk '
    /Name: AeroSpace/ { found = 1; next }
    found && /Disposition:/ {
      if ($0 ~ /enabled/) print "enabled"
      else print "disabled"
      exit
    }
  ')
  print "${disposition:-absent}"
}

current_aerospace_process_state() {
  if [[ -n $process_state_file && -f $process_state_file ]]; then
    cat "$process_state_file"
  elif $test_mode; then
    print stopped
  elif /usr/bin/pgrep -x AeroSpace >/dev/null 2>&1; then
    print running
  else
    print stopped
  fi
}

run_aerospace_open() {
  if [[ -n $open_command ]]; then
    "$open_command"
  else
    /usr/bin/open -a AeroSpace
  fi
}

run_aerospace_quit() {
  if [[ -n $quit_command ]]; then
    "$quit_command"
  else
    /usr/bin/osascript -e 'tell application "AeroSpace" to quit' >/dev/null 2>&1 || true
  fi
}

active_aerospace_config() {
  local xdg_config="$omacos_home/.config/aerospace/aerospace.toml"
  local dot_config="$omacos_home/.aerospace.toml"
  if [[ -f $xdg_config ]]; then
    print -r -- "$xdg_config"
  elif [[ -f $dot_config ]]; then
    print -r -- "$dot_config"
  else
    print -r -- "$xdg_config"
  fi
}

write_temporary_login_preference() {
  local config_path=$1
  local enabled=$2
  mkdir -p "${config_path:h}"
  if [[ ! -f $config_path ]]; then
    cp "$omacos_root/config/aerospace/aerospace.toml" "$config_path"
  fi
  if /usr/bin/grep -q '^start-at-login[[:space:]]*=' "$config_path"; then
    /usr/bin/sed -i '' -E "s/^start-at-login[[:space:]]*=.*/start-at-login = $enabled/" "$config_path"
  else
    print "start-at-login = $enabled" >> "$config_path"
  fi
}

wait_for_aerospace_command() {
  [[ -n $open_command ]] && return 0
  local attempt
  for attempt in {1..30}; do
    if "$aerospace_command" list-workspaces --all >/dev/null 2>&1; then
      "$aerospace_command" reload-config >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.1
  done
}

restore_aerospace_lifecycle() {
  [[ -f $lifecycle_directory/login-item-before.txt ]] || return 0
  local desired_login_state
  local desired_process_state
  desired_login_state=$(<"$lifecycle_directory/login-item-before.txt")
  desired_process_state=$(<"$lifecycle_directory/process-before.txt")

  if [[ -z $open_command && ! -d /Applications/AeroSpace.app ]]; then
    return 0
  fi

  local config_path
  local temporary_directory
  local config_backup
  local config_existed=false
  config_path=$(active_aerospace_config)
  temporary_directory=$(mktemp -d -t omacos-aerospace-lifecycle.XXXXXX)
  config_backup="$temporary_directory/aerospace.toml"
  if [[ -f $config_path ]]; then
    cp "$config_path" "$config_backup"
    config_existed=true
  fi

  local preference=false
  [[ $desired_login_state == enabled ]] && preference=true
  write_temporary_login_preference "$config_path" "$preference"
  run_aerospace_open
  wait_for_aerospace_command
  run_aerospace_quit

  if $config_existed; then
    cp "$config_backup" "$config_path"
  else
    rm -f "$config_path"
  fi
  rm -rf "$temporary_directory"

  if [[ $desired_process_state == running ]]; then
    run_aerospace_open
  fi
}

case ${1:-} in
  capture-before)
    mkdir -p "$lifecycle_directory"
    current_aerospace_login_state > "$lifecycle_directory/login-item-before.txt"
    current_aerospace_process_state > "$lifecycle_directory/process-before.txt"
    ;;
  restore-before)
    restore_aerospace_lifecycle
    ;;
  status)
    print "login-item=$(current_aerospace_login_state)"
    print "process=$(current_aerospace_process_state)"
    ;;
  *)
    print -u2 "Usage: aerospace-lifecycle.zsh <capture-before|restore-before|status>"
    exit 1
    ;;
esac
