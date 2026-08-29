#!/bin/zsh

set -euo pipefail

if [[ -n ${OMACOS_FAKE_CAPTURE_LOG:-} ]]; then
  print -l -- "$@" > "$OMACOS_FAKE_CAPTURE_LOG"
fi

output_path=${@[-1]}
mkdir -p "${output_path:h}"
touch "$output_path"
