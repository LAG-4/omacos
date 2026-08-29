#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_home=$(mktemp -d -t omacos-plugin-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
plugin_command=(env OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$project_root" "$project_root/scripts/plugins.zsh")

plugin_count=$(jq '.plugins | length' "$project_root/config/plugin-catalog.json")
(( plugin_count == 29 ))
inventory_ids=$(jq -c '[.shellPlugins[].id] | sort' "$project_root/docs/quattro-inventory.json")
catalog_ids=$(jq -c '[.plugins[].id] | sort' "$project_root/config/plugin-catalog.json")
[[ $catalog_ids == "$inventory_ids" ]]
"${plugin_command[@]}" install "$project_root/test/fixtures/example-plugin" >/dev/null
"${plugin_command[@]}" enable example.status
output=$("${plugin_command[@]}" run example.status inspect)
jq -e '.title == "Example Status" and .summary == "inspect"' <<< "$output" >/dev/null
"${plugin_command[@]}" disable example.status
"${plugin_command[@]}" remove example.status

print 'Out-of-process plugin contract tests passed'
