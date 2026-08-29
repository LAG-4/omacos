#!/bin/zsh

set -euo pipefail

networksetup_command=${OMACOS_NETWORKSETUP:-/usr/sbin/networksetup}
security_command=${OMACOS_SECURITY:-/usr/bin/security}

wifi_device() {
  "$networksetup_command" -listallhardwareports | awk '
    /Hardware Port: (Wi-Fi|AirPort)/ { found=1; next }
    found && /Device:/ { print $2; exit }
  '
}

wifi_ssid() {
  local device
  local output
  device=$(wifi_device)
  [[ -n $device ]] || { print -u2 'No Wi-Fi interface was found.'; return 1; }
  output=$("$networksetup_command" -getairportnetwork "$device")
  if [[ $output == *': '* ]]; then
    print -r -- "${output#*: }"
  else
    print -u2 'This Mac is not connected to Wi-Fi.'
    return 1
  fi
}

wifi_password() {
  local ssid=$1
  "$security_command" find-generic-password -D 'AirPort network password' -a "$ssid" -w 2>/dev/null \
    || "$security_command" find-generic-password -l "$ssid" -w
}

escape_wifi_qr_value() {
  sed -e 's/\\/\\\\/g' -e 's/;/\\;/g' -e 's/,/\\,/g' -e 's/:/\\:/g' <<< "$1" | tr -d '\n'
}

wifi_credentials() {
  local ssid
  local password
  local escaped_ssid
  local escaped_password
  ssid=$(wifi_ssid)
  if ! password=$(wifi_password "$ssid"); then
    print -u2 'The Wi-Fi password was not found in this user’s keychain.'
    return 1
  fi
  escaped_ssid=$(escape_wifi_qr_value "$ssid")
  escaped_password=$(escape_wifi_qr_value "$password")
  jq -nc --arg ssid "$ssid" --arg password "$password" \
    --arg payload "WIFI:T:WPA;S:$escaped_ssid;P:$escaped_password;;" \
    '{schemaVersion:1,ssid:$ssid,password:$password,security:"WPA",payload:$payload}'
}

case ${1:-status} in
  status|ssid) wifi_ssid ;;
  password) wifi_password "$(wifi_ssid)" ;;
  credentials|wifi-qr) wifi_credentials ;;
  settings) open 'x-apple.systempreferences:com.apple.wifi-settings-extension' ;;
  *) print -u2 'Usage: omacos network <status|password|credentials|settings>'; exit 1 ;;
esac
