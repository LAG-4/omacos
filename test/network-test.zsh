#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
credentials=$(OMACOS_NETWORKSETUP="$project_root/test/fixtures/fake-networksetup.zsh" \
  OMACOS_SECURITY="$project_root/test/fixtures/fake-security.zsh" \
  "$project_root/scripts/network.zsh" credentials)
jq -e '.ssid == "OMacOS Test WiFi" and .password == "secret:semicolon;pass" and .payload == "WIFI:T:WPA;S:OMacOS Test WiFi;P:secret\\:semicolon\\;pass;;"' <<< "$credentials" >/dev/null

print 'Wi-Fi credential and QR payload tests passed'
