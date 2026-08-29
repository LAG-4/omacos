#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-parity-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT
generated_json="$temporary_directory/parity.json"
generated_markdown="$temporary_directory/parity.md"

"$project_root/scripts/generate-parity-ledger.zsh" \
  "$project_root/docs/quattro-inventory.json" \
  "$generated_json" \
  "$generated_markdown" >/dev/null

cmp "$project_root/docs/quattro-parity.json" "$generated_json"
cmp "$project_root/docs/quattro-parity.md" "$generated_markdown"

jq -e '
  .schemaVersion == 1
  and .summary.total == 879
  and .summary.pending == 0
  and (.summary.implemented + .summary.limited + .summary.pending + .summary.unavailable + .summary.notApplicable == .summary.total)
  and (.items.manual | length) == 51
  and (.items.plugins | length) == 29
  and (.items.cliGroups | length) == 68
  and (.items.bindings | length) == 192
  and (.items.dynamicBindingFamilies | length) == 3
  and (.items.menuEntries | length) == 328
  and (.items.packages | length) == 208
  and ([.items[][] | .implementationStatus | IN("implemented", "limited", "pending", "unavailable", "not-applicable")] | all)
  and ([.items[][] | .grade | IN("exact", "close-substitute", "native-replacement", "optional-unsafe", "impossible", "not-applicable")] | all)
' "$generated_json" >/dev/null

OMACOS_PARITY_LEDGER="$generated_json" "$project_root/scripts/parity.zsh" summary | rg -q '^total=879$'
OMACOS_PARITY_LEDGER="$generated_json" "$project_root/scripts/parity.zsh" show plugin omarchy.bar | jq -e '.implementationStatus == "implemented"' >/dev/null

routed_groups="$temporary_directory/routed-groups.txt"
awk '
  /^case \$\{1:-help\} in$/ { in_router=1; next }
  in_router && /^  [a-z0-9_|-]+\)$/ {
    route=$0
    sub(/^  /, "", route)
    sub(/\)$/, "", route)
    count=split(route, groups, "|")
    for (i=1; i<=count; i++) print groups[i]
  }
' "$project_root/bin/omacos" | sort -u > "$routed_groups"

while IFS= read -r group; do
  if ! rg -Fxq "$group" "$routed_groups"; then
    print -u2 "Implemented Quattro CLI group has no OMacOS route: $group"
    exit 1
  fi
done < <(jq -r '.items.cliGroups[] | select(.implementationStatus == "implemented") | .id' "$generated_json")

print 'Exhaustive Quattro parity ledger test passed'
