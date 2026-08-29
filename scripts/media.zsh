#!/bin/zsh

set -euo pipefail

osascript_command=${OMACOS_OSASCRIPT:-/usr/bin/osascript}

media_status_script='tell application "System Events"
  if exists process "Spotify" then
    tell application "Spotify"
      return (player state as text) & tab & (name of current track) & tab & (artist of current track) & tab & "Spotify"
    end tell
  else if exists process "Music" then
    tell application "Music"
      if player state is stopped then return "stopped" & tab & "" & tab & "" & tab & "Music"
      return (player state as text) & tab & (name of current track) & tab & (artist of current track) & tab & "Music"
    end tell
  end if
end tell
return "stopped" & tab & "" & tab & "" & tab & ""'

status_media() {
  local output
  local playback_state
  local title
  local artist
  local application
  output=$($osascript_command -e "$media_status_script" 2>/dev/null || print $'stopped\t\t\t')
  IFS=$'\t' read -r playback_state title artist application <<< "$output"
  jq -nc \
    --arg state "${playback_state:-stopped}" \
    --arg title "${title:-}" \
    --arg artist "${artist:-}" \
    --arg application "${application:-}" \
    '{schemaVersion:1,state:$state,title:$title,artist:$artist,application:$application}'
}

control_media() {
  local action=$1
  local spotify_action
  local music_action
  case $action in
    play-pause)
      spotify_action='playpause'
      music_action='playpause'
      ;;
    next)
      spotify_action='next track'
      music_action='next track'
      ;;
    previous)
      spotify_action='previous track'
      music_action='previous track'
      ;;
    *)
      print -u2 'Usage: omacos media <status|play-pause|next|previous>'
      return 1
      ;;
  esac

  $osascript_command -e "tell application \"System Events\"
    if exists process \"Spotify\" then
      tell application \"Spotify\" to $spotify_action
    else if exists process \"Music\" then
      tell application \"Music\" to $music_action
    end if
  end tell" >/dev/null
}

case ${1:-status} in
  status|show)
    status_media
    ;;
  play-pause|next|previous)
    control_media "$1"
    ;;
  *)
    print -u2 'Usage: omacos media <status|play-pause|next|previous>'
    exit 1
    ;;
esac
