#!/bin/zsh

[[ -n ${OMACOS_FAKE_BREW_LOG:-} ]] && print -r -- "$*" >> "$OMACOS_FAKE_BREW_LOG"
if [[ ${1:-} == "list" && ${3:-} == "firefox" ]]; then
  exit 0
fi
