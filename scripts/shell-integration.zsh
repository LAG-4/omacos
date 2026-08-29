#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
state_directory="$omacos_home/.local/state/omacos"
zshrc_path="$omacos_home/.zshrc"
start_marker="# >>> OMacOS shell integration >>>"
end_marker="# <<< OMacOS shell integration <<<"
action=${1:-}

remove_managed_block() {
  local source_path=$1
  local output_path=$2
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$source_path" > "$output_path"
}

case $action in
  install)
    mkdir -p "$state_directory"
    if [[ ! -f $zshrc_path ]]; then
      touch "$zshrc_path"
      touch "$state_directory/created-zshrc"
    fi

    if ! rg -Fq "$start_marker" "$zshrc_path"; then
      {
        print "$start_marker"
        print "source \"$project_root/config/shell/omacos.zsh\""
        print "$end_marker"
      } >> "$zshrc_path"
    fi
    ;;
  remove)
    if [[ ! -f $zshrc_path ]] || ! rg -Fq "$start_marker" "$zshrc_path"; then
      exit 0
    fi

    temporary_zshrc=$(mktemp -t omacos-zshrc.XXXXXX)
    trap 'rm -f "$temporary_zshrc"' EXIT
    remove_managed_block "$zshrc_path" "$temporary_zshrc"
    mv "$temporary_zshrc" "$zshrc_path"

    if [[ -f $state_directory/created-zshrc && ! -s $zshrc_path ]]; then
      rm -f "$zshrc_path"
    fi
    ;;
  *)
    print -u2 "Usage: shell-integration.zsh <install|remove>"
    exit 1
    ;;
esac
