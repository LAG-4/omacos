#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_home=$(mktemp -d -t omacos-services-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_CURL="$project_root/test/fixtures/fake-weather-curl.zsh" \
  "$project_root/scripts/weather.zsh" location --set Cupertino 37.3230,-122.0322 >/dev/null

weather=$(OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_CURL="$project_root/test/fixtures/fake-weather-curl.zsh" \
  "$project_root/scripts/weather.zsh" refresh)
jq -e '.location == "Cupertino" and .temperatureC == 21 and (.forecast | length) == 3' <<< "$weather" >/dev/null

media=$(OMACOS_OSASCRIPT="$project_root/test/fixtures/fake-media-osascript.zsh" \
  "$project_root/scripts/media.zsh" status)
jq -e '.state == "playing" and .title == "Test Track" and .application == "Music"' <<< "$media" >/dev/null
FAKE_MEDIA_CONTROL=true OMACOS_OSASCRIPT="$project_root/test/fixtures/fake-media-osascript.zsh" \
  "$project_root/scripts/media.zsh" next

toggle_command=(env OMACOS_TEST_HOME="$temporary_home" OMACOS_TEST_MODE=true "$project_root/scripts/toggles.zsh")
"${toggle_command[@]}" toggle idle >/dev/null
jq -e '.name == "stay-awake" and .enabled == true' <<< "$("${toggle_command[@]}" status idle)" >/dev/null
[[ -f $temporary_home/Library/LaunchAgents/dev.omacos.stay-awake.plist ]]
"${toggle_command[@]}" disable idle
jq -e '.enabled == false' <<< "$("${toggle_command[@]}" status idle)" >/dev/null
[[ ! -f $temporary_home/Library/LaunchAgents/dev.omacos.stay-awake.plist ]]
"${toggle_command[@]}" screensaver >/dev/null
"${toggle_command[@]}" lock >/dev/null
"${toggle_command[@]}" sleep >/dev/null

print 'Weather, media, and toggle adapter tests passed'
