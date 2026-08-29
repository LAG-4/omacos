#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
capture_directory=${OMACOS_CAPTURE_DIRECTORY:-$omacos_home/Pictures/Screenshots}
screencapture_binary=${OMACOS_SCREENCAPTURE_BINARY:-/usr/sbin/screencapture}
shell_binary=${OMACOS_SHELL_BINARY:-$omacos_home/.local/bin/omacos-shell}
action=${1:-}

timestamped_path() {
  local extension=$1
  print "$capture_directory/$(date '+%Y-%m-%d_%H-%M-%S').$extension"
}

require_shell_binary() {
  if [[ ! -x $shell_binary ]]; then
    print -u2 "OMacOS native shell is required for on-device recognition: $shell_binary"
    exit 1
  fi
}

mkdir -p "$capture_directory"

case $action in
  screenshot)
    output_path=$(timestamped_path png)
    if [[ ${2:-} == "--screen" ]]; then
      "$screencapture_binary" -x "$output_path"
    else
      "$screencapture_binary" -i "$output_path"
    fi
    if [[ -f $output_path ]]; then
      print "$output_path"
    else
      print "Screenshot cancelled."
    fi
    ;;
  recording)
    output_path=$(timestamped_path mov)
    if [[ ${2:-} == "--microphone" ]]; then
      "$screencapture_binary" -i -J video -g "$output_path"
    else
      "$screencapture_binary" -i -J video "$output_path"
    fi
    if [[ -f $output_path ]]; then
      print "$output_path"
    else
      print "Screen recording cancelled."
    fi
    ;;
  text)
    require_shell_binary
    temporary_image=$(mktemp -t omacos-ocr.XXXXXX.png)
    trap 'rm -f "$temporary_image"' EXIT
    "$screencapture_binary" -i -s "$temporary_image"
    if [[ ! -f $temporary_image ]]; then
      print "Text capture cancelled."
      exit 0
    fi
    recognized_text=$("$shell_binary" --recognize-text "$temporary_image")
    if [[ -z $recognized_text ]]; then
      print "No text was recognized."
      exit 0
    fi
    print -n "$recognized_text" | pbcopy
    print "$recognized_text"
    ;;
  color)
    open -a "Digital Color Meter"
    ;;
  *)
    print -u2 "Usage: omacos capture <screenshot|recording|text|color> [--screen|--microphone]"
    exit 1
    ;;
esac
