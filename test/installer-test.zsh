#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-installer-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/install.sh" --dry-run)

if [[ $output != *"Dry run complete. No files or packages were changed."* ]]; then
  print -u2 "Installer dry-run test failed: completion message missing"
  exit 1
fi

if [[ -n $(find "$temporary_home" -mindepth 1 -print -quit) ]]; then
  print -u2 "Installer dry-run test failed: dry run wrote into the test home"
  exit 1
fi

print "Installer dry-run test passed"

set +e
missing_terminal_output=$(
  OMACOS_CONFIRMATION_DEVICE="$temporary_home/missing-terminal" \
    OMACOS_TEST_HOME="$temporary_home" \
    OMACOS_TEST_MODE=true \
    "$project_root/install.sh" </dev/null 2>&1
)
missing_terminal_status=$?
set -e

if (( missing_terminal_status == 0 )) || [[ $missing_terminal_output != *"OMacOS confirmation failed: no interactive terminal is available."* ]]; then
  print -u2 "Installer terminal test failed: unavailable confirmation terminal was not reported as an error"
  exit 1
fi

print "Installer unavailable-terminal test passed"

temporary_undo_home=$(mktemp -d -t omacos-undo-test.XXXXXX)
trap 'rm -rf "$temporary_home" "$temporary_undo_home"' EXIT
undo_output=$(OMACOS_TEST_HOME="$temporary_undo_home" "$project_root/uninstall.sh" --yes)

if [[ $undo_output != *"No installed or locally running OMacOS environment was found."* ]]; then
  print -u2 "Local undo test failed: empty-state result was not explained"
  exit 1
fi

print "Local undo test passed"
