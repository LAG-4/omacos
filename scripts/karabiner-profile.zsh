#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
karabiner_config="$omacos_home/.config/karabiner/karabiner.json"
managed_rules=${OMACOS_KARABINER_RULES:-$omacos_home/.config/karabiner/assets/complex_modifications/omacos-super-key.json}
[[ -f $managed_rules ]] || managed_rules="$project_root/config/karabiner/omacos-super-key.json"
action=${1:-}

enable_managed_rules() {
  local temporary_config

  [[ -f $managed_rules ]] || { print -u2 "OMacOS Karabiner rules are missing: $managed_rules"; return 1; }
  mkdir -p "${karabiner_config:h}"

  if [[ ! -f $karabiner_config ]]; then
    cat > "$karabiner_config" <<'EOF'
{
  "profiles": [
    {
      "name": "Default profile",
      "selected": true,
      "virtual_hid_keyboard": {
        "keyboard_type_v2": "ansi"
      }
    }
  ]
}
EOF
  fi

  if ! jq -e '.profiles | type == "array" and length > 0 and any(.[]; .selected == true)' "$karabiner_config" >/dev/null; then
    print -u2 "Karabiner has no selected profile in $karabiner_config"
    return 1
  fi

  temporary_config=$(mktemp "${karabiner_config:h}/omacos-karabiner.XXXXXX")
  trap 'rm -f "$temporary_config"' EXIT
  jq --slurpfile managed "$managed_rules" '
    ($managed[0].rules // []) as $omacos_rules
    | ($omacos_rules | map(.description)) as $omacos_descriptions
    | .profiles |= map(
        if .selected == true then
          .complex_modifications = (
            (.complex_modifications // {})
            + {
                "rules": (
                  ((.complex_modifications.rules // [])
                    | map(select(.description as $description | ($omacos_descriptions | index($description)) == null)))
                  + $omacos_rules
                )
              }
          )
        else
          .
        end
      )
  ' "$karabiner_config" > "$temporary_config"
  mv "$temporary_config" "$karabiner_config"
  trap - EXIT
}

remove_managed_rules() {
  local temporary_config

  [[ -f $karabiner_config ]] || return 0
  temporary_config=$(mktemp "${karabiner_config:h}/omacos-karabiner.XXXXXX")
  trap 'rm -f "$temporary_config"' EXIT
  jq '
    [
      "Use Right Option as the OMacOS Super layer",
      "Hold F9 for OMacOS dictation",
      "Use OMacOS Super with pointer gestures"
    ] as $omacos_descriptions
    | .profiles |= map(
        if .complex_modifications.rules? then
          .complex_modifications.rules |= map(
            select(.description as $description | ($omacos_descriptions | index($description)) == null)
          )
        else
          .
        end
      )
  ' "$karabiner_config" > "$temporary_config"
  mv "$temporary_config" "$karabiner_config"
  trap - EXIT
}

managed_rules_enabled() {
  [[ -f $karabiner_config ]] || return 1
  jq -e '
    [.profiles[] | select(.selected == true) | .complex_modifications.rules[]?.description]
    | index("Use Right Option as the OMacOS Super layer") != null
  ' "$karabiner_config" >/dev/null
}

case $action in
  enable)
    enable_managed_rules
    print "Enabled the OMacOS Super rules in the selected Karabiner profile."
    ;;
  remove)
    remove_managed_rules
    ;;
  status)
    if managed_rules_enabled; then
      print "enabled"
    else
      print "disabled"
      exit 1
    fi
    ;;
  *)
    print -u2 "Usage: karabiner-profile.zsh <enable|remove|status>"
    exit 1
    ;;
esac
