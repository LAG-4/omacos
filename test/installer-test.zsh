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

