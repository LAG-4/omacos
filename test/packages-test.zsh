#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_directory=$(mktemp -d -t omacos-package-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT
brew_log="$temporary_directory/brew.log"

package_count=$(jq '.packages | length' "$project_root/config/optional-packages.json")
(( package_count >= 30 ))
OMACOS_BREW="$project_root/test/fixtures/fake-brew.zsh" OMACOS_FAKE_BREW_LOG="$brew_log" \
  "$project_root/scripts/packages.zsh" status firefox | grep -qx installed
OMACOS_BREW="$project_root/test/fixtures/fake-brew.zsh" OMACOS_FAKE_BREW_LOG="$brew_log" \
  "$project_root/scripts/packages.zsh" install vlc --yes
grep -qx 'install --cask vlc' "$brew_log"

print 'Optional package catalog tests passed'
