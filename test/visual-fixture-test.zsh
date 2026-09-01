#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-visual-fixture-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

"$project_root/.build/debug/omacos-shell" --render-visual-fixtures "$temporary_directory" >/dev/null

expected_fixtures=(bar-horizontal bar-vertical command-menu system-panel)
for fixture in "${expected_fixtures[@]}"; do
  fixture_path="$temporary_directory/$fixture.png"
  [[ -s $fixture_path ]]
  file "$fixture_path" | grep -Fq 'PNG image data'
done

horizontal_height=$(sips -g pixelHeight "$temporary_directory/bar-horizontal.png" | awk '/pixelHeight/ { print $2 }')
vertical_width=$(sips -g pixelWidth "$temporary_directory/bar-vertical.png" | awk '/pixelWidth/ { print $2 }')
[[ $horizontal_height == 26 || $horizontal_height == 52 ]]
[[ $vertical_width == 28 || $vertical_width == 56 ]]

print "Headless shell visual fixture test passed"
