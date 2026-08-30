#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-defaults-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

if [[ $(OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/defaults.zsh" get terminal) != "ghostty" ]]; then
  print -u2 "Defaults test failed: terminal default was not initialized"
  exit 1
fi

OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/defaults.zsh" set browser brave >/dev/null
if [[ $(OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/defaults.zsh" get browser) != "brave" ]]; then
  print -u2 "Defaults test failed: browser default was not saved"
  exit 1
fi

open_log="$temporary_home/open-arguments"
OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_FAKE_OPEN_LOG="$open_log" \
  OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
  "$project_root/scripts/launch.zsh" browser "https://example.com"

if ! rg -Fxq -- "Brave Browser" "$open_log" || ! rg -Fxq -- "https://example.com" "$open_log"; then
  print -u2 "Launch test failed: selected browser did not receive the URL"
  exit 1
fi

: > "$open_log"
OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_FAKE_OPEN_LOG="$open_log" \
  OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
  "$project_root/scripts/launch.zsh" app calculator
rg -Fxq -- "Calculator" "$open_log"

: > "$open_log"
OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_FAKE_OPEN_LOG="$open_log" \
  OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
  "$project_root/scripts/launch.zsh" web chatgpt
rg -Fxq -- "https://chatgpt.com" "$open_log"

: > "$open_log"
OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_FAKE_OPEN_LOG="$open_log" \
  OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
  "$project_root/scripts/launch.zsh" terminal
rg -Fxq -- "Ghostty" "$open_log"
rg -Fxq -- "--command=/bin/zsh" "$open_log"

set +e
invalid_output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/defaults.zsh" set editor unknown 2>&1)
invalid_status=$?
set -e
if (( invalid_status == 0 )) || [[ $invalid_output != *"Unsupported OMacOS default"* ]]; then
  print -u2 "Defaults test failed: unsupported editor was accepted"
  exit 1
fi

print "Application defaults and launch adapter test passed"
