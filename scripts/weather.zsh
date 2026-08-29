#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
curl_command=${OMACOS_CURL:-/usr/bin/curl}
config_directory="$omacos_home/.config/omacos"
state_directory="$omacos_home/.local/state/omacos"
config_file="$config_directory/weather.json"
cache_file="$state_directory/weather.json"

print_usage() {
  print -u2 'Usage: omacos weather <show|refresh|location [--set NAME [LAT,LON]|--clear]>'
}

ensure_weather_config() {
  mkdir -p "$config_directory" "$state_directory"
  if [[ ! -f $config_file ]]; then
    print -r -- '{"schemaVersion":1,"location":"","coordinates":""}' > "$config_file"
  fi
}

weather_query() {
  local location
  local coordinates
  location=$(jq -r '.location // ""' "$config_file")
  coordinates=$(jq -r '.coordinates // ""' "$config_file")
  if [[ -n $coordinates ]]; then
    print -r -- "$coordinates"
  else
    print -r -- "$location"
  fi
}

refresh_weather() {
  local query
  local encoded_query
  local weather_url
  local temporary_file
  query=$(weather_query)
  encoded_query=$(jq -rn --arg query "$query" '$query | @uri')
  weather_url="https://wttr.in/$encoded_query?format=j1"
  temporary_file=$(mktemp "$state_directory/.weather.XXXXXX")

  if ! "$curl_command" -fsSL --connect-timeout 5 --max-time 12 -A OMacOS "$weather_url" > "$temporary_file" \
    || ! jq -e '.current_condition[0].temp_C and .current_condition[0].weatherDesc[0].value' "$temporary_file" >/dev/null 2>&1; then
    rm -f "$temporary_file"
    print -u2 'OMacOS weather could not refresh. Existing cached data was preserved.'
    return 1
  fi
  mv "$temporary_file" "$cache_file"
}

show_weather() {
  if [[ ! -f $cache_file ]]; then
    refresh_weather
  fi
  jq -c '{
    schemaVersion: 1,
    location: (.nearest_area[0].areaName[0].value // "Current location"),
    region: (.nearest_area[0].region[0].value // ""),
    temperatureC: (.current_condition[0].temp_C | tonumber),
    feelsLikeC: (.current_condition[0].FeelsLikeC | tonumber),
    description: .current_condition[0].weatherDesc[0].value,
    humidity: (.current_condition[0].humidity | tonumber),
    windKmph: (.current_condition[0].windspeedKmph | tonumber),
    forecast: [.weather[0:3][] | {
      date,
      minimumC: (.mintempC | tonumber),
      maximumC: (.maxtempC | tonumber),
      description: (.hourly[4].weatherDesc[0].value // .hourly[0].weatherDesc[0].value)
    }]
  }' "$cache_file"
}

set_location() {
  local location=${1:-}
  local coordinates=${2:-}
  local coordinate_pattern='^[-+]?[0-9]+([.][0-9]+)?,[-+]?[0-9]+([.][0-9]+)?$'
  if [[ -z $location ]]; then
    print -u2 'Weather location cannot be empty.'
    return 1
  fi
  if [[ -n $coordinates && ! $coordinates =~ $coordinate_pattern ]]; then
    print -u2 'Coordinates must use LAT,LON, for example 34.0259,-118.7798.'
    return 1
  fi
  jq -n --arg location "$location" --arg coordinates "$coordinates" \
    '{schemaVersion: 1, location: $location, coordinates: $coordinates}' > "$config_file"
  print "Weather location set to $location${coordinates:+ ($coordinates)}."
}

ensure_weather_config
case ${1:-show} in
  show|status)
    show_weather
    ;;
  refresh)
    refresh_weather
    show_weather
    ;;
  location)
    case ${2:-} in
      --set)
        set_location "${3:-}" "${4:-}"
        ;;
      --clear)
        print -r -- '{"schemaVersion":1,"location":"","coordinates":""}' > "$config_file"
        print 'Weather location reset to automatic detection.'
        ;;
      '')
        jq -r 'if (.location // "") == "" then "Automatic location" else .location + (if (.coordinates // "") == "" then "" else " (" + .coordinates + ")" end) end' "$config_file"
        ;;
      *)
        print_usage
        exit 1
        ;;
    esac
    ;;
  *)
    print_usage
    exit 1
    ;;
esac
