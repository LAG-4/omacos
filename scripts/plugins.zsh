#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
installed_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
user_plugin_directory="$omacos_home/.config/omacos/plugins"
state_file="$omacos_home/.config/omacos/plugin-state.json"
catalog="$installed_root/config/plugin-catalog.json"
mkdir -p "$user_plugin_directory" "${state_file:h}"
[[ -f $state_file ]] || print -r -- '{"schemaVersion":1,"enabled":[]}' > "$state_file"

validate_plugin_id() {
  local plugin_id=$1
  local pattern='^[a-z0-9][a-z0-9.-]+$'
  [[ $plugin_id =~ $pattern ]] || { print -u2 "Invalid plugin id: $plugin_id"; return 1; }
}

user_manifest() {
  local plugin_id=$1
  local manifest="$user_plugin_directory/$plugin_id/manifest.json"
  [[ -f $manifest ]] || { print -u2 "User plugin not found: $plugin_id"; return 1; }
  print -r -- "$manifest"
}

set_enabled() {
  local plugin_id=$1
  local enabled=$2
  local temporary_state
  temporary_state=$(mktemp "${state_file:h}/.plugin-state.XXXXXX")
  if $enabled; then
    jq --arg id "$plugin_id" '.enabled = ((.enabled + [$id]) | unique)' "$state_file" > "$temporary_state"
  else
    jq --arg id "$plugin_id" '.enabled = [.enabled[] | select(. != $id)]' "$state_file" > "$temporary_state"
  fi
  mv "$temporary_state" "$state_file"
}

case ${1:-list} in
  list)
    jq -r '.plugins[] | [.id,.name,.grade,.implementation] | @tsv' "$catalog"
    for manifest in "$user_plugin_directory"/*/manifest.json(N); do
      jq -r --argjson enabled "$(jq --arg id "$(jq -r .id "$manifest")" '.enabled | index($id) != null' "$state_file")" \
        '[.id,.name,(if $enabled then "enabled" else "disabled" end),"out-of-process provider"] | @tsv' "$manifest"
    done
    ;;
  install)
    source_directory=${2:-}
    manifest="$source_directory/manifest.json"
    [[ -f $manifest ]] || { print -u2 'Plugin directory must contain manifest.json.'; exit 1; }
    jq -e '.schemaVersion == 1 and (.id | type == "string") and (.name | length > 0) and (.provider.command | length > 0)' "$manifest" >/dev/null
    plugin_id=$(jq -r '.id' "$manifest")
    validate_plugin_id "$plugin_id"
    [[ $plugin_id != omacos.* && $plugin_id != omarchy.* ]] || { print -u2 'Reserved plugin namespace.'; exit 1; }
    provider=$(jq -r '.provider.command' "$manifest")
    [[ $provider != /* && $provider != *'..'* && -x $source_directory/$provider ]] || { print -u2 'Plugin provider must be an executable file inside the plugin directory.'; exit 1; }
    rm -rf "$user_plugin_directory/$plugin_id"
    cp -a "$source_directory" "$user_plugin_directory/$plugin_id"
    print "Installed plugin $plugin_id."
    ;;
  enable|disable)
    plugin_id=${2:-}
    validate_plugin_id "$plugin_id"
    user_manifest "$plugin_id" >/dev/null
    if [[ $1 == "enable" ]]; then set_enabled "$plugin_id" true; else set_enabled "$plugin_id" false; fi
    ;;
  remove)
    plugin_id=${2:-}
    validate_plugin_id "$plugin_id"
    user_manifest "$plugin_id" >/dev/null
    rm -rf "$user_plugin_directory/$plugin_id"
    set_enabled "$plugin_id" false
    ;;
  run)
    plugin_id=${2:-}
    action=${3:-status}
    manifest=$(user_manifest "$plugin_id")
    jq -e --arg id "$plugin_id" '.enabled | index($id) != null' "$state_file" >/dev/null \
      || { print -u2 "Plugin is disabled: $plugin_id"; exit 1; }
    provider=$(jq -r '.provider.command' "$manifest")
    plugin_directory=${manifest:h}
    output=$("$plugin_directory/$provider" "$action" "${@:4}")
    jq -e '.schemaVersion == 1 and (type == "object")' <<< "$output" >/dev/null \
      || { print -u2 'Plugin provider returned invalid JSON.'; exit 1; }
    print -r -- "$output"
    ;;
  *) print -u2 'Usage: omacos plugin <list|install DIR|enable ID|disable ID|remove ID|run ID ACTION...>'; exit 1 ;;
esac
