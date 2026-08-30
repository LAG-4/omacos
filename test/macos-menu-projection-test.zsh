#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
inventory="$project_root/docs/quattro-inventory.json"
projection="$project_root/Sources/OMacOSShell/Resources/macos-menu-projection.json"

[[ -f $projection ]]

jq -e '
  .schemaVersion == 1
  and (.hiddenEntryRoots | type == "array" and length > 0)
  and (.replacementLabels | type == "object" and length > 0)
' "$projection" >/dev/null

jq -n -e --slurpfile inventory "$inventory" --slurpfile projection "$projection" '
  def hidden($id):
    any($projection[0].hiddenEntryRoots[]; . as $root | $id == $root or ($id | startswith($root + ".")));

  [
    $inventory[0].menuEntries[]
    | select(hidden(.id) | not)
    | .label = ($projection[0].replacementLabels[.id] // .label)
  ] as $entries
  | ($entries | map(.id)) as $ids
  | ($entries | map(.label)) as $labels
  | ($ids | index("install.aur") == null)
  and ($ids | index("system.hibernate") == null)
  and ($ids | index("setup.config.hyprland") == null)
  and ($ids | index("update.config.plymouth") == null)
  and ($labels | index("AUR") == null)
  and ($labels | index("Hyprland") == null)
  and ($labels | index("Arch") == null)
  and ($labels | index("Plymouth") == null)
  and ($entries | any(.id == "install.package" and .label == "Homebrew Apps"))
  and ($entries | any(.id == "learn.arch" and .label == "macOS User Guide"))
  and ($entries | any(.id == "style.hyprland" and .label == "Window Manager"))
  and ($entries | any(.id == "update.firmware" and .label == "Software Update"))
  and ($entries | any(.id == "trigger.toggle.nightlight" and .label == "Night Shift Settings"))
  and ($entries | any(.id == "trigger.toggle.notifications" and .label == "Pause OMacOS Reminders"))
  and (
    $entries
    | all(
        (.id | contains(".")) as $has_parent
        | if $has_parent then
            (.id | split(".") | .[0:-1] | join(".")) as $parent
            | $ids | index($parent) != null
          else
            true
          end
      )
  )
' >/dev/null

rg -Fq 'projection.apply(to: inventory.menuEntries)' "$project_root/Sources/OMacOSShell/OMacOSMenuStore.swift"
rg -Fq 'TextField("Search OMacOS actions"' "$project_root/Sources/OMacOSShell/OMacOSCommandMenuView.swift"

print "macOS command-menu projection test passed"
