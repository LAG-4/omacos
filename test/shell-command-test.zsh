#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
shell_binary="$project_root/.build/debug/omacos-shell"
temporary_home=$(mktemp -d -t omacos-shell-command-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

mkdir -p "$temporary_home/.local/bin"
ln -s "$shell_binary" "$temporary_home/.local/bin/omacos-shell"

OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" shell toggle-panel audio
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" shell toggle-panel weather
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" shell toggle-panel dev-gallery
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" osd
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" shell toggle-panel permissions
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" shell toggle-menu
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" dictation toggle
OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --clipboard-clear
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" bar position bottom >/dev/null
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" bar position left >/dev/null
OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" bar transparency enable >/dev/null
bar_status=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" bar status)
jq -e '.position == "left" and .transparent == true' <<< "$bar_status" >/dev/null

set +e
invalid_output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" shell toggle-panel missing 2>&1)
invalid_status=$?
set -e

if (( invalid_status == 0 )) || [[ $invalid_output != *"Unknown shell panel: missing"* ]]; then
  print -u2 "Shell command test failed: invalid panel was not rejected"
  exit 1
fi

set +e
binary_invalid_output=$("$shell_binary" --toggle-panel missing 2>&1)
binary_invalid_status=$?
set -e

if (( binary_invalid_status != 2 )) || [[ $binary_invalid_output != *"Unknown OMacOS shell panel."* ]]; then
  print -u2 "Shell command test failed: native shell accepted an invalid panel"
  exit 1
fi

print "Native shell command routing test passed"
