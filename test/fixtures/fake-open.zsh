#!/bin/zsh

set -euo pipefail

print -l -- "$@" > "$OMACOS_FAKE_OPEN_LOG"
