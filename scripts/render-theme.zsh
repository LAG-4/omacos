#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
theme_slug=${1:-tokyo-night}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
theme_source="$project_root/themes/$theme_slug.json"
generated_directory="$omacos_home/.config/omacos/generated"
ghostty_theme_directory="$omacos_home/.config/ghostty/themes"

if [[ ! -f $theme_source ]]; then
  print -u2 "OMacOS theme not found: $theme_slug"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  print -u2 "OMacOS theme rendering requires jq"
  exit 1
fi

mkdir -p "$generated_directory" "$ghostty_theme_directory"
cp "$theme_source" "$generated_directory/shell-theme.json"

background=$(jq -r '.colors.background' "$theme_source")
foreground=$(jq -r '.colors.foreground' "$theme_source")
selection=$(jq -r '.colors.selection' "$theme_source")
accent=$(jq -r '.colors.accent' "$theme_source")
red=$(jq -r '.colors.red' "$theme_source")
green=$(jq -r '.colors.green' "$theme_source")
yellow=$(jq -r '.colors.yellow' "$theme_source")
blue=$(jq -r '.colors.blue' "$theme_source")
magenta=$(jq -r '.colors.magenta' "$theme_source")
cyan=$(jq -r '.colors.cyan' "$theme_source")

{
  print "background = $background"
  print "foreground = $foreground"
  print "selection-background = $selection"
  print "selection-foreground = $foreground"
  print "palette = 1=$red"
  print "palette = 2=$green"
  print "palette = 3=$yellow"
  print "palette = 4=$blue"
  print "palette = 5=$magenta"
  print "palette = 6=$cyan"
} > "$ghostty_theme_directory/OMacOS"

cat > "$generated_directory/start-borders" <<EOF
#!/bin/zsh
exec /opt/homebrew/bin/borders active_color=0xff${accent#\#} inactive_color=0xff${selection#\#} width=5.0 hidpi=on
EOF
chmod +x "$generated_directory/start-borders"

print "Applied OMacOS theme: $theme_slug"

