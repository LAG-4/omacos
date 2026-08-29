#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-config-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

jq -e '.schemaVersion == 1 and .slug == "tokyo-night"' "$project_root/themes/tokyo-night.json" >/dev/null
cmp "$project_root/themes/tokyo-night.json" "$project_root/Sources/OMacOSShell/Resources/default-theme.json"

generated_karabiner="$temporary_home/omacos-super-key.json"
"$project_root/scripts/generate-karabiner-config.zsh" "$project_root/config/keybindings.json" "$generated_karabiner" >/dev/null
jq -e '.title == "OMacOS Super key"' "$generated_karabiner" >/dev/null

expected_binding_count=$(jq '.bindings | length' "$project_root/config/keybindings.json")
generated_manipulator_count=$(jq '.rules[0].manipulators | length' "$generated_karabiner")
if (( generated_manipulator_count != expected_binding_count + 1 )); then
  print -u2 "Keybinding config test failed: generated profile is incomplete"
  exit 1
fi

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

print "Config generation test passed"
