#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
reference_root=${OMARCHY_REFERENCE_ROOT:-/Users/lag/Developer/omarchy}
output_path=${1:-$project_root/docs/quattro-inventory.json}
expected_commit=${OMARCHY_REFERENCE_COMMIT:-0b3f1b7ead00ac4bcbaae8bac16bab3f7efbe516}

if [[ ! -d $reference_root/.git ]]; then
  print -u2 "Omarchy reference checkout not found: $reference_root"
  exit 1
fi

actual_commit=$(git -C "$reference_root" rev-parse HEAD)
if [[ $actual_commit != $expected_commit ]]; then
  print -u2 "Omarchy reference is $actual_commit; expected frozen Quattro commit $expected_commit"
  exit 1
fi

temporary_directory=$(mktemp -d -t omacos-quattro-inventory.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

manual_jsonl="$temporary_directory/manual.jsonl"
for manual_path in "$reference_root"/manual/*.md; do
  manual_file=${manual_path:t}
  manual_title=$(sed -n 's/^# //p' "$manual_path" | head -n 1)
  jq -nc --arg id "${manual_file%.md}" --arg file "manual/$manual_file" --arg title "$manual_title" \
    '{id: $id, file: $file, title: $title}' >> "$manual_jsonl"
done

plugin_jsonl="$temporary_directory/plugins.jsonl"
find "$reference_root/shell/plugins" -name manifest.json -print | sort | while IFS= read -r manifest_path; do
  jq -c --arg source "${manifest_path#$reference_root/}" \
    '{id, name, description, version, source: $source}' "$manifest_path" >> "$plugin_jsonl"
done

group_tsv="$temporary_directory/groups.tsv"
sed -n 's/^GROUP_DESCRIPTIONS\[\([^]]*\)\]="\([^"]*\)"/\1\	\2/p' "$reference_root/bin/omarchy" > "$group_tsv"

binding_jsonl="$temporary_directory/bindings.jsonl"
find "$reference_root/default/hypr/bindings" -maxdepth 1 -name '*.lua' -print | sort | while IFS= read -r binding_path; do
  source_path=${binding_path#$reference_root/}
  awk '/o\.bind\(|o\.bind_toggle\(/ { print NR "\t" $0 }' "$binding_path" | while IFS=$'\t' read -r line_number declaration; do
    jq -nc --arg source "$source_path" --argjson line "$line_number" --arg declaration "$declaration" \
      '{source: $source, line: $line, declaration: $declaration}' >> "$binding_jsonl"
  done
done

menu_ids_jsonl="$temporary_directory/menu-ids.jsonl"
sed -n 's/^[[:space:]]*"\([^"]*\)".*/\1/p' "$reference_root/default/omarchy/omarchy-menu.jsonc" | while IFS= read -r menu_id; do
  jq -nc --arg id "$menu_id" '{id: $id}' >> "$menu_ids_jsonl"
done

packages_jsonl="$temporary_directory/packages.jsonl"
for package_path in "$reference_root"/install/omarchy-base.packages "$reference_root"/install/omarchy-other.packages; do
  source_path=${package_path#$reference_root/}
  while IFS= read -r package_name; do
    [[ -z $package_name || $package_name == \#* ]] && continue
    jq -nc --arg name "$package_name" --arg source "$source_path" '{name: $name, source: $source}' >> "$packages_jsonl"
  done < "$package_path"
done

jq -n \
  --arg commit "$actual_commit" \
  --slurpfile manual "$manual_jsonl" \
  --slurpfile plugins "$plugin_jsonl" \
  --rawfile groupTSV "$group_tsv" \
  --slurpfile bindings "$binding_jsonl" \
  --slurpfile menuEntries "$menu_ids_jsonl" \
  --slurpfile packages "$packages_jsonl" \
  '{
    schemaVersion: 1,
    reference: {
      repository: "https://github.com/basecamp/omarchy",
      branch: "quattro",
      commit: $commit
    },
    manual: $manual,
    shellPlugins: $plugins,
    cliGroups: ($groupTSV | split("\n") | map(select(length > 0) | split("\t") | {id: .[0], description: .[1]})),
    staticBindingDeclarations: $bindings,
    dynamicBindingFamilies: [
      {id: "workspaces", source: "default/hypr/bindings/tiling.lua", expansion: "workspaces 1 through 10: focus, move and silent move"},
      {id: "group-windows", source: "default/hypr/bindings/tiling.lua", expansion: "group windows 1 through 5"},
      {id: "bar-panels", source: "default/hypr/bindings/utilities.lua", expansion: "right-side bar panels 1 through 9"}
    ],
    menuEntries: $menuEntries,
    defaultPackages: $packages
  }' > "$output_path"

print "Generated frozen Quattro inventory: $output_path"
