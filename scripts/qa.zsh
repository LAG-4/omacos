#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
shell_binary=${OMACOS_SHELL_BINARY:-$omacos_home/.local/bin/omacos-shell}
[[ -x $shell_binary ]] || shell_binary="$project_root/.build/debug/omacos-shell"

case ${1:-report} in
  report)
    [[ -x $shell_binary ]] || { print -u2 "OMacOS native shell is unavailable: $shell_binary"; exit 1; }
    output_path=${2:-}
    report=$($shell_binary --hardware-report)
    if [[ -n $output_path ]]; then
      mkdir -p "${output_path:h}"
      print -r -- "$report" > "$output_path"
      print "$output_path"
    else
      print -r -- "$report"
    fi
    ;;
  checklist)
    print "$project_root/docs/hardware-validation.md"
    ;;
  *) print -u2 'Usage: omacos qa <report [OUTPUT.json]|checklist>'; exit 1 ;;
esac
