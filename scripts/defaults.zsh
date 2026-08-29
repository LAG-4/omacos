#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
defaults_path="$omacos_home/.config/omacos/defaults.json"
action=${1:-}

initialize_defaults() {
  if [[ -f $defaults_path ]]; then
    return
  fi

  mkdir -p "${defaults_path:h}"
  jq -n '{schemaVersion: 1, terminal: "ghostty", browser: "system", editor: "nvim"}' > "$defaults_path"
}

validate_default() {
  local category=$1
  local value=$2

  case "$category:$value" in
    terminal:ghostty|terminal:terminal|terminal:iterm2) ;;
    browser:system|browser:safari|browser:chrome|browser:brave|browser:firefox|browser:helium) ;;
    editor:nvim|editor:vscode|editor:cursor|editor:zed|editor:sublime) ;;
    *)
      print -u2 "Unsupported OMacOS default: $category=$value"
      return 1
      ;;
  esac
}

initialize_defaults

case $action in
  init)
    print "$defaults_path"
    ;;
  get)
    category=${2:-}
    if [[ $category != "terminal" && $category != "browser" && $category != "editor" ]]; then
      print -u2 "Usage: omacos default get <terminal|browser|editor>"
      exit 1
    fi
    jq -r --arg category "$category" '.[$category]' "$defaults_path"
    ;;
  set)
    category=${2:-}
    value=${3:-}
    validate_default "$category" "$value"
    temporary_defaults=$(mktemp -t omacos-defaults.XXXXXX)
    trap 'rm -f "$temporary_defaults"' EXIT
    jq --arg category "$category" --arg value "$value" '.[$category] = $value' "$defaults_path" > "$temporary_defaults"
    mv "$temporary_defaults" "$defaults_path"
    print "Set OMacOS default $category to $value"
    ;;
  list)
    jq . "$defaults_path"
    ;;
  *)
    print -u2 "Usage: omacos default <get CATEGORY|set CATEGORY VALUE|list>"
    exit 1
    ;;
esac
