#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-webapps-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/webapps.zsh" install "Test App" "https://example.com/path?q=one" >/dev/null
app_directory="$temporary_home/Applications/OMacOS Web Apps/Test App.app"

if [[ ! -x $app_directory/Contents/MacOS/launcher ]] \
  || [[ $(plutil -extract CFBundleDisplayName raw "$app_directory/Contents/Info.plist") != "Test App" ]]; then
  print -u2 "Web app test failed: application bundle is incomplete"
  exit 1
fi

if [[ $(OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/webapps.zsh" list) != "Test App" ]]; then
  print -u2 "Web app test failed: installed app was not listed"
  exit 1
fi

OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/webapps.zsh" remove "Test App" >/dev/null
if [[ -e $app_directory ]]; then
  print -u2 "Web app test failed: removed app bundle remains"
  exit 1
fi

set +e
invalid_output=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/webapps.zsh" install "Bad/App" "file:///tmp/demo" 2>&1)
invalid_status=$?
set -e
if (( invalid_status == 0 )) || [[ $invalid_output != *"Web app names may contain"* ]]; then
  print -u2 "Web app test failed: unsafe name was accepted"
  exit 1
fi

print "Web app bundle lifecycle test passed"
