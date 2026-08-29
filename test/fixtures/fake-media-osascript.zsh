#!/bin/zsh

if [[ ${FAKE_MEDIA_CONTROL:-false} == "true" ]]; then
  exit 0
fi
print -r -- $'playing\tTest Track\tTest Artist\tMusic'
