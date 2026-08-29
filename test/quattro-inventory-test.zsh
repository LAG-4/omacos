#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
inventory="$project_root/docs/quattro-inventory.json"

jq -e '.schemaVersion == 1 and .reference.branch == "quattro" and .reference.commit == "0b3f1b7ead00ac4bcbaae8bac16bab3f7efbe516"' "$inventory" >/dev/null

manual_count=$(jq '.manual | length' "$inventory")
plugin_count=$(jq '.shellPlugins | length' "$inventory")
group_count=$(jq '.cliGroups | length' "$inventory")
binding_count=$(jq '.staticBindingDeclarations | length' "$inventory")
menu_count=$(jq '.menuEntries | length' "$inventory")
package_count=$(jq '.defaultPackages | length' "$inventory")

if (( manual_count != 51 )); then
  print -u2 "Quattro inventory test failed: expected 51 manual chapters, found $manual_count"
  exit 1
fi

if (( plugin_count != 29 )); then
  print -u2 "Quattro inventory test failed: expected 29 shell plugins, found $plugin_count"
  exit 1
fi

if (( group_count < 65 || binding_count < 80 || menu_count < 150 || package_count < 100 )); then
  print -u2 "Quattro inventory test failed: one or more source inventories are unexpectedly incomplete"
  exit 1
fi

jq -e '
  ["omarchy.agents", "omarchy.bar", "omarchy.clipboard", "omarchy.emojis", "omarchy.image-picker", "omarchy.lock", "omarchy.menu", "omarchy.notifications", "omarchy.osd", "omarchy.reminders", "omarchy.audio", "omarchy.bluetooth", "omarchy.clock", "omarchy.monitor", "omarchy.network", "omarchy.power", "omarchy.weather", "omarchy.media", "omarchy.idle", "omarchy.nightlight"]
  - [.shellPlugins[].id]
  | length == 0
' "$inventory" >/dev/null

print "Frozen Quattro inventory test passed"
