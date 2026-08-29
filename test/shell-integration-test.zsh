#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-shell-integration-test.XXXXXX)
empty_home=$(mktemp -d -t omacos-empty-shell-integration-test.XXXXXX)
trap 'rm -rf "$temporary_home" "$empty_home"' EXIT

print "original user line" > "$temporary_home/.zshrc"
OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/shell-integration.zsh" install
print "later user line" >> "$temporary_home/.zshrc"
OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/shell-integration.zsh" remove

if ! rg -Fxq "original user line" "$temporary_home/.zshrc" \
  || ! rg -Fxq "later user line" "$temporary_home/.zshrc" \
  || rg -Fq "OMacOS shell integration" "$temporary_home/.zshrc"; then
  print -u2 "Shell integration test failed: uninstall did not preserve unrelated user edits"
  exit 1
fi

OMACOS_TEST_HOME="$empty_home" "$project_root/scripts/shell-integration.zsh" install
OMACOS_TEST_HOME="$empty_home" "$project_root/scripts/shell-integration.zsh" remove
if [[ -e $empty_home/.zshrc ]]; then
  print -u2 "Shell integration test failed: uninstall left an OMacOS-created .zshrc"
  exit 1
fi

print "Reversible shell integration test passed"
