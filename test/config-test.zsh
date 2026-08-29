#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-config-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

jq -e '.schemaVersion == 1 and .slug == "tokyo-night"' "$project_root/themes/tokyo-night.json" >/dev/null
cmp "$project_root/themes/tokyo-night.json" "$project_root/Sources/OMacOSShell/Resources/default-theme.json"

theme_count=0
for theme_path in "$project_root"/themes/*.json; do
  jq -e '
    .schemaVersion == 1
    and (.slug | length > 0)
    and (.mode == "dark" or .mode == "light")
    and ([.colors[] | test("^#[0-9A-Fa-f]{6}$")] | all)
  ' "$theme_path" >/dev/null
  (( theme_count += 1 ))
done

if (( theme_count != 22 )); then
  print -u2 "Theme config test failed: expected 22 Quattro themes, found $theme_count"
  exit 1
fi

generated_karabiner="$temporary_home/omacos-super-key.json"
"$project_root/scripts/generate-karabiner-config.zsh" "$project_root/config/keybindings.json" "$generated_karabiner" >/dev/null
jq -e '.title == "OMacOS Super key"' "$generated_karabiner" >/dev/null

expected_binding_count=$(jq '.bindings | length' "$project_root/config/keybindings.json")
generated_manipulator_count=$(jq '.rules[0].manipulators | length' "$generated_karabiner")
if (( generated_manipulator_count != expected_binding_count + 1 )); then
  print -u2 "Keybinding config test failed: generated profile is incomplete"
  exit 1
fi
jq -e '.rules[1].manipulators[0].from.key_code == "f9" and (.rules[1].manipulators[0].to_after_key_up | length) == 1' "$generated_karabiner" >/dev/null

if jq -e '.bindings[].command | select(test("/aerospace( |$)"))' "$project_root/config/keybindings.json" >/dev/null; then
  print -u2 "Keybinding config test failed: a window-manager command bypasses the OMacOS adapter"
  exit 1
fi

jq -e '[.bindings[].command | select(contains("omacos wm"))] | length >= 40' "$project_root/config/keybindings.json" >/dev/null

OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/render-theme.zsh" tokyo-night >/dev/null

if [[ ! -f $temporary_home/.config/omacos/generated/shell-theme.json ]]; then
  print -u2 "Theme config test failed: shell theme was not generated"
  exit 1
fi

if [[ ! -x $temporary_home/.config/omacos/generated/start-borders ]]; then
  print -u2 "Theme config test failed: border launcher was not generated"
  exit 1
fi

if [[ ! -f $temporary_home/.config/ghostty/themes/OMacOS ]]; then
  print -u2 "Theme config test failed: Ghostty theme was not generated"
  exit 1
fi

for generated_target in kitty.conf alacritty.toml btop.theme tmux.conf vscode.json zed.json; do
  if [[ ! -s $temporary_home/.config/omacos/generated/tool-themes/$generated_target ]]; then
    print -u2 "Theme config test failed: $generated_target was not generated"
    exit 1
  fi
done

jq -e '.schemaVersion == 1 and (.targets | length == 8)' "$temporary_home/.config/omacos/generated/theme-targets.json" >/dev/null

print "Config generation test passed"
