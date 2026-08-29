#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-reminder-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

mkdir -p "$temporary_home/.local/bin"
ln -s "$project_root/.build/debug/omacos-shell" "$temporary_home/.local/bin/omacos-shell"

add_output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" reminder add 5m "water plants")
if [[ $add_output != *$'\twater plants' ]]; then
  print -u2 "Reminder test failed: add did not return the stored reminder"
  exit 1
fi

list_output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" reminder list)
if [[ $list_output != *$'\tpending\twater plants' ]]; then
  print -u2 "Reminder test failed: list did not include the pending reminder"
  exit 1
fi

OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" reminder clear
if [[ -n $(OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" reminder list) ]]; then
  print -u2 "Reminder test failed: clear left reminders behind"
  exit 1
fi

set +e
invalid_output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/bin/omacos" reminder add someday "invalid" 2>&1)
invalid_status=$?
set -e
if (( invalid_status == 0 )) || [[ $invalid_output != *"Invalid reminder duration"* ]]; then
  print -u2 "Reminder test failed: invalid duration was accepted"
  exit 1
fi

print "Local reminder lifecycle test passed"
