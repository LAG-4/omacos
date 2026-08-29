#!/bin/zsh

set -euo pipefail

osascript_command=${OMACOS_OSASCRIPT:-/usr/bin/osascript}
magick_command=${OMACOS_MAGICK:-magick}
ffmpeg_command=${OMACOS_FFMPEG:-ffmpeg}

transcode_file() {
  local input_path=$1
  local output_format=$2
  [[ -f $input_path ]] || { print -u2 "Input file does not exist: $input_path"; return 1; }

  local output_path="${input_path:r}-omacos.$output_format"
  case $output_format in
    png|jpg|jpeg|webp|heic)
      "$magick_command" "$input_path" "$output_path"
      ;;
    gif)
      "$ffmpeg_command" -y -i "$input_path" -vf "fps=15,scale=1280:-1:flags=lanczos" "$output_path"
      ;;
    mp4)
      "$ffmpeg_command" -y -i "$input_path" -c:v libx264 -crf 20 -c:a aac -movflags +faststart "$output_path"
      ;;
    mov)
      "$ffmpeg_command" -y -i "$input_path" -c:v prores_ks -profile:v 3 -c:a pcm_s16le "$output_path"
      ;;
    mp3)
      "$ffmpeg_command" -y -i "$input_path" -vn -c:a libmp3lame -q:a 2 "$output_path"
      ;;
    *) print -u2 "Unsupported output format: $output_format"; return 1 ;;
  esac
  print "$output_path"
}

case ${1:-} in
  file)
    [[ -n ${2:-} && -n ${3:-} ]] || { print -u2 "Usage: omacos transcode file INPUT FORMAT"; exit 1; }
    transcode_file "$2" "${3:l}"
    ;;
  choose)
    input_path=$("$osascript_command" -e 'POSIX path of (choose file with prompt "Choose media to transcode")')
    [[ -n $input_path ]] || exit 0
    output_format=$("$osascript_command" -e 'choose from list {"png", "jpg", "webp", "gif", "mp4", "mov", "mp3"} with prompt "Output format"' -e 'if result is false then return ""' -e 'item 1 of result')
    [[ -n $output_format ]] || exit 0
    transcode_file "$input_path" "$output_format"
    ;;
  *) print -u2 "Usage: omacos transcode <choose|file INPUT FORMAT>"; exit 1 ;;
esac
