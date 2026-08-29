#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
reference_root=${OMARCHY_REFERENCE_ROOT:-/Users/lag/Developer/omarchy}
expected_commit=${OMARCHY_REFERENCE_COMMIT:-0b3f1b7ead00ac4bcbaae8bac16bab3f7efbe516}
output_directory=${1:-$project_root/themes}

if [[ $(git -C "$reference_root" rev-parse HEAD) != $expected_commit ]]; then
  print -u2 "Theme import requires frozen Omarchy commit $expected_commit"
  exit 1
fi

toml_value() {
  local key=$1
  local file=$2
  sed -n "s/^${key}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -n 1
}

mkdir -p "$output_directory"

for colors_file in "$reference_root"/themes/*/colors.toml; do
  slug=${colors_file:h:t}
  name=${(C)${slug//-/ }}
  mode=$(toml_value mode "$colors_file")
  accent=$(toml_value accent "$colors_file")
  selection=$(toml_value selection "$colors_file")
  muted=$(toml_value muted "$colors_file")
  background=$(toml_value background "$colors_file")
  dark_background=$(toml_value dark_background "$colors_file")
  darker_background=$(toml_value darker_background "$colors_file")
  lighter_background=$(toml_value lighter_background "$colors_file")
  foreground=$(toml_value foreground "$colors_file")
  dark_foreground=$(toml_value dark_foreground "$colors_file")
  light_foreground=$(toml_value light_foreground "$colors_file")
  bright_foreground=$(toml_value bright_foreground "$colors_file")
  red=$(toml_value red "$colors_file")
  yellow=$(toml_value yellow "$colors_file")
  orange=$(toml_value orange "$colors_file")
  green=$(toml_value green "$colors_file")
  cyan=$(toml_value cyan "$colors_file")
  blue=$(toml_value blue "$colors_file")
  magenta=$(toml_value magenta "$colors_file")
  bright_red=$(toml_value bright_red "$colors_file")
  bright_yellow=$(toml_value bright_yellow "$colors_file")
  bright_green=$(toml_value bright_green "$colors_file")
  bright_cyan=$(toml_value bright_cyan "$colors_file")
  bright_blue=$(toml_value bright_blue "$colors_file")
  bright_magenta=$(toml_value bright_magenta "$colors_file")

  [[ -n $orange ]] || orange=$red

  jq -n \
    --arg name "$name" --arg slug "$slug" --arg mode "$mode" \
    --arg accent "$accent" --arg selection "$selection" --arg muted "$muted" \
    --arg background "$background" --arg darkBackground "$dark_background" \
    --arg darkerBackground "$darker_background" --arg lighterBackground "$lighter_background" \
    --arg foreground "$foreground" --arg darkForeground "$dark_foreground" \
    --arg lightForeground "$light_foreground" --arg brightForeground "$bright_foreground" \
    --arg red "$red" --arg yellow "$yellow" --arg orange "$orange" --arg green "$green" \
    --arg cyan "$cyan" --arg blue "$blue" --arg magenta "$magenta" \
    --arg brightRed "$bright_red" --arg brightYellow "$bright_yellow" \
    --arg brightGreen "$bright_green" --arg brightCyan "$bright_cyan" \
    --arg brightBlue "$bright_blue" --arg brightMagenta "$bright_magenta" \
    '{
      schemaVersion: 1,
      name: $name,
      slug: $slug,
      mode: $mode,
      colors: {
        accent: $accent,
        selection: $selection,
        muted: $muted,
        background: $background,
        darkBackground: $darkBackground,
        darkerBackground: $darkerBackground,
        lighterBackground: $lighterBackground,
        foreground: $foreground,
        darkForeground: $darkForeground,
        lightForeground: $lightForeground,
        brightForeground: $brightForeground,
        red: $red,
        yellow: $yellow,
        orange: $orange,
        green: $green,
        cyan: $cyan,
        blue: $blue,
        magenta: $magenta,
        brightRed: $brightRed,
        brightYellow: $brightYellow,
        brightGreen: $brightGreen,
        brightCyan: $brightCyan,
        brightBlue: $brightBlue,
        brightMagenta: $brightMagenta
      }
    }' > "$output_directory/$slug.json"
done

print "Imported $(find "$output_directory" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ') semantic themes."
