#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-qa-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT
report_path="$temporary_directory/hardware.json"

OMACOS_SHELL_BINARY="$project_root/.build/debug/omacos-shell" \
  "$project_root/scripts/qa.zsh" report "$report_path" >/dev/null

jq -e '
  .schemaVersion == 1
  and (.macOSVersion | length > 0)
  and (.architecture | length > 0)
  and (.displayCount == (.displays | length))
  and (.permissions.schemaVersion == 1)
  and (has("serialNumber") | not)
  and (has("hardwareUUID") | not)
' "$report_path" >/dev/null

checklist=$("$project_root/scripts/qa.zsh" checklist)
[[ $checklist == "$project_root/docs/hardware-validation.md" ]]

print 'Privacy-safe hardware QA report test passed'
