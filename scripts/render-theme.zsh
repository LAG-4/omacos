#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
theme_slug=${1:-tokyo-night}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
theme_source="$project_root/themes/$theme_slug.json"
generated_directory="$omacos_home/.config/omacos/generated"
tool_theme_directory="$generated_directory/tool-themes"
ghostty_theme_directory="$omacos_home/.config/ghostty/themes"

if [[ ! -f $theme_source ]]; then
  print -u2 "OMacOS theme not found: $theme_slug"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  print -u2 "OMacOS theme rendering requires jq"
  exit 1
fi

mkdir -p "$generated_directory" "$tool_theme_directory" "$ghostty_theme_directory"
cp "$theme_source" "$generated_directory/shell-theme.json"

background=$(jq -r '.colors.background' "$theme_source")
foreground=$(jq -r '.colors.foreground' "$theme_source")
selection=$(jq -r '.colors.selection' "$theme_source")
accent=$(jq -r '.colors.accent' "$theme_source")
muted=$(jq -r '.colors.muted' "$theme_source")
red=$(jq -r '.colors.red' "$theme_source")
green=$(jq -r '.colors.green' "$theme_source")
yellow=$(jq -r '.colors.yellow' "$theme_source")
blue=$(jq -r '.colors.blue' "$theme_source")
magenta=$(jq -r '.colors.magenta' "$theme_source")
cyan=$(jq -r '.colors.cyan' "$theme_source")
bright_red=$(jq -r '.colors.brightRed // .colors.red' "$theme_source")
bright_green=$(jq -r '.colors.brightGreen // .colors.green' "$theme_source")
bright_yellow=$(jq -r '.colors.brightYellow // .colors.yellow' "$theme_source")
bright_blue=$(jq -r '.colors.brightBlue // .colors.blue' "$theme_source")
bright_magenta=$(jq -r '.colors.brightMagenta // .colors.magenta' "$theme_source")
bright_cyan=$(jq -r '.colors.brightCyan // .colors.cyan' "$theme_source")

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

cat > "$tool_theme_directory/kitty.conf" <<EOF
background $background
foreground $foreground
selection_background $selection
selection_foreground $foreground
color1 $red
color2 $green
color3 $yellow
color4 $blue
color5 $magenta
color6 $cyan
color9 $bright_red
color10 $bright_green
color11 $bright_yellow
color12 $bright_blue
color13 $bright_magenta
color14 $bright_cyan
EOF

cat > "$tool_theme_directory/alacritty.toml" <<EOF
[colors.primary]
background = "$background"
foreground = "$foreground"

[colors.selection]
background = "$selection"
text = "$foreground"

[colors.normal]
black = "$background"
red = "$red"
green = "$green"
yellow = "$yellow"
blue = "$blue"
magenta = "$magenta"
cyan = "$cyan"
white = "$foreground"

[colors.bright]
black = "$selection"
red = "$bright_red"
green = "$bright_green"
yellow = "$bright_yellow"
blue = "$bright_blue"
magenta = "$bright_magenta"
cyan = "$bright_cyan"
white = "$foreground"
EOF

cat > "$tool_theme_directory/btop.theme" <<EOF
theme[main_bg]="$background"
theme[main_fg]="$foreground"
theme[title]="$accent"
theme[hi_fg]="$accent"
theme[selected_bg]="$selection"
theme[selected_fg]="$foreground"
theme[inactive_fg]="$muted"
theme[cpu_box]="$blue"
theme[mem_box]="$magenta"
theme[net_box]="$cyan"
theme[proc_box]="$green"
theme[div_line]="$selection"
theme[temp_start]="$green"
theme[temp_mid]="$yellow"
theme[temp_end]="$red"
EOF

cat > "$tool_theme_directory/tmux.conf" <<EOF
set -g status-style "bg=$background,fg=$foreground"
set -g message-style "bg=$selection,fg=$foreground"
set -g pane-border-style "fg=$selection"
set -g pane-active-border-style "fg=$accent"
set -g window-status-current-style "bg=$accent,fg=$background,bold"
EOF

jq -n \
  --arg background "$background" --arg foreground "$foreground" \
  --arg selection "$selection" --arg accent "$accent" \
  --arg red "$red" --arg yellow "$yellow" --arg green "$green" \
  --arg cyan "$cyan" --arg blue "$blue" --arg magenta "$magenta" \
  '{
    "workbench.colorCustomizations": {
      "editor.background": $background,
      "editor.foreground": $foreground,
      "editor.selectionBackground": $selection,
      "focusBorder": $accent,
      "errorForeground": $red,
      "editorWarning.foreground": $yellow,
      "editorInfo.foreground": $blue,
      "terminal.ansiGreen": $green,
      "terminal.ansiCyan": $cyan,
      "terminal.ansiMagenta": $magenta
    }
  }' > "$tool_theme_directory/vscode.json"

jq -n \
  --arg background "$background" --arg foreground "$foreground" \
  --arg selection "$selection" --arg accent "$accent" \
  '{
    "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
    name: "OMacOS",
    author: "OMacOS",
    themes: [{
      name: "OMacOS",
      appearance: "dark",
      style: {
        "background": $background,
        "text": $foreground,
        "element.selected": $selection,
        "border.focused": $accent
      }
    }]
  }' > "$tool_theme_directory/zed.json"

jq -n \
  --arg shell "$generated_directory/shell-theme.json" \
  --arg ghostty "$ghostty_theme_directory/OMacOS" \
  --arg kitty "$tool_theme_directory/kitty.conf" \
  --arg alacritty "$tool_theme_directory/alacritty.toml" \
  --arg btop "$tool_theme_directory/btop.theme" \
  --arg tmux "$tool_theme_directory/tmux.conf" \
  --arg vscode "$tool_theme_directory/vscode.json" \
  --arg zed "$tool_theme_directory/zed.json" \
  '{schemaVersion: 1, targets: {shell: $shell, ghostty: $ghostty, kitty: $kitty, alacritty: $alacritty, btop: $btop, tmux: $tmux, vscode: $vscode, zed: $zed}}' \
  > "$generated_directory/theme-targets.json"

cat > "$generated_directory/start-borders" <<EOF
#!/bin/zsh
exec /opt/homebrew/bin/borders active_color=0xff${accent#\#} inactive_color=0xff${selection#\#} width=5.0 hidpi=on
EOF
chmod +x "$generated_directory/start-borders"

print "Applied OMacOS theme: $theme_slug"
