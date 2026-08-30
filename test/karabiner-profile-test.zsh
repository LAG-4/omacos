#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-karabiner-profile-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

managed_rules="$temporary_home/.config/karabiner/assets/complex_modifications/omacos-super-key.json"
mkdir -p "${managed_rules:h}"
"$project_root/scripts/generate-karabiner-config.zsh" "$project_root/config/keybindings.json" "$managed_rules" >/dev/null

OMACOS_ROOT="$project_root" OMACOS_TEST_HOME="$temporary_home" \
  "$project_root/scripts/karabiner-profile.zsh" enable >/dev/null
OMACOS_ROOT="$project_root" OMACOS_TEST_HOME="$temporary_home" \
  "$project_root/scripts/karabiner-profile.zsh" enable >/dev/null

karabiner_config="$temporary_home/.config/karabiner/karabiner.json"
if [[ ! -f $karabiner_config ]]; then
  print -u2 "Karabiner profile test failed: a first-install profile was not created"
  exit 1
fi

if [[ $(jq '[.profiles[] | select(.selected == true) | .complex_modifications.rules[] | select(.description == "Use Right Option as the OMacOS Super layer")] | length' "$karabiner_config") != "1" ]]; then
  print -u2 "Karabiner profile test failed: enabling twice did not leave exactly one OMacOS Super rule"
  exit 1
fi

if [[ $(jq '[.profiles[] | select(.selected == true) | .complex_modifications.rules[] | select(.description == "Hold F9 for OMacOS dictation" or .description == "Use OMacOS Super with pointer gestures")] | length' "$karabiner_config") != "2" ]]; then
  print -u2 "Karabiner profile test failed: dictation and pointer rules were not enabled"
  exit 1
fi

if [[ $(OMACOS_ROOT="$project_root" OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/karabiner-profile.zsh" status) != "enabled" ]]; then
  print -u2 "Karabiner profile test failed: enabled status was not detected"
  exit 1
fi

OMACOS_ROOT="$project_root" OMACOS_TEST_HOME="$temporary_home" \
  "$project_root/scripts/karabiner-profile.zsh" remove

if jq -e '[.profiles[] | .complex_modifications.rules[]?.description] | index("Use Right Option as the OMacOS Super layer") != null' "$karabiner_config" >/dev/null; then
  print -u2 "Karabiner profile test failed: managed rules remained after removal"
  exit 1
fi

print "Karabiner selected-profile activation test passed"
