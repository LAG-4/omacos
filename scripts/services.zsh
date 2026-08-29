#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
tailscale_command=${OMACOS_TAILSCALE:-}
pgrep_command=${OMACOS_PGREP:-/usr/bin/pgrep}
du_command=${OMACOS_DU:-/usr/bin/du}

find_tailscale() {
  if [[ -n $tailscale_command ]]; then
    print -r -- "$tailscale_command"
  elif command -v tailscale >/dev/null 2>&1; then
    command -v tailscale
  elif [[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
    print '/Applications/Tailscale.app/Contents/MacOS/Tailscale'
  else
    return 1
  fi
}

tailscale_status() {
  local command_path
  local raw_status
  command_path=$(find_tailscale) || {
    jq -nc '{schemaVersion:1,installed:false,online:false,tailnet:"",machines:[]}'
    return
  }
  raw_status=$($command_path status --json)
  jq -c '{
    schemaVersion: 1,
    installed: true,
    online: (.Self.Online // false),
    tailnet: (.CurrentTailnet.Name // ""),
    machines: ([.Peer[]? | {
      id: (.ID // .StableID // .DNSName),
      name: (.HostName // (.DNSName | split(".")[0]) // "Machine"),
      dnsName: (.DNSName // ""),
      ip: (.TailscaleIPs[0] // ""),
      online: (.Online // false)
    }] | sort_by(.name))
  }' <<< "$raw_status"
}

dropbox_status() {
  local running=false
  local storage_kb=0
  local dropbox_directory=''
  if $pgrep_command -x Dropbox >/dev/null 2>&1; then running=true; fi
  for candidate in "$omacos_home"/Library/CloudStorage/Dropbox*(N/) "$omacos_home"/Dropbox(N/); do
    dropbox_directory=$candidate
    storage_kb=$($du_command -sk "$candidate" 2>/dev/null | awk '{print $1}')
    break
  done
  jq -nc --argjson running "$running" --arg path "$dropbox_directory" --argjson storageKB "${storage_kb:-0}" \
    '{schemaVersion:1,installed:($path != ""),running:$running,path:$path,storageKB:$storageKB}'
}

case ${1:-} in
  tailscale)
    command_path=$(find_tailscale 2>/dev/null || true)
    case ${2:-status} in
      status) tailscale_status ;;
      up|down) [[ -n $command_path ]] || { print -u2 'Tailscale is not installed.'; exit 1; }; "$command_path" "$2" ;;
      send)
        [[ -n $command_path && -n ${3:-} && -n ${4:-} ]] || { print -u2 'Usage: omacos service tailscale send MACHINE FILE...'; exit 1; }
        "$command_path" file cp "${@:4}" "${3}:"
        ;;
      open) open -a Tailscale ;;
      *) print -u2 'Usage: omacos service tailscale <status|up|down|send MACHINE FILE...|open>'; exit 1 ;;
    esac
    ;;
  dropbox)
    case ${2:-status} in
      status) dropbox_status ;;
      open) open -a Dropbox ;;
      folder)
        dropbox_path=$(dropbox_status | jq -r '.path')
        [[ -n $dropbox_path ]] || { print -u2 'Dropbox folder was not found.'; exit 1; }
        open "$dropbox_path"
        ;;
      *) print -u2 'Usage: omacos service dropbox <status|open|folder>'; exit 1 ;;
    esac
    ;;
  *) print -u2 'Usage: omacos service <tailscale|dropbox> ACTION'; exit 1 ;;
esac
