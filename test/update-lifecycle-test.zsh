#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_home=$(mktemp -d -t omacos-update-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

OMACOS_TEST_HOME="$temporary_home" OMACOS_TEST_MODE=true "$project_root/install.sh" --yes >/dev/null
installed_cli="$temporary_home/.local/bin/omacos"
installed_root="$temporary_home/.local/share/omacos/current"
[[ $(<"$temporary_home/.config/omacos/update-channel") == "stable" ]]
[[ $(OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$installed_cli" update status) == *'Update channel: stable'* ]]
print 'pre-update managed config' > "$temporary_home/.config/aerospace/aerospace.toml"

OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_TEST_MODE=true \
  OMACOS_ROOT="$installed_root" \
  OMACOS_UPDATE_SOURCE="$project_root" \
  "$installed_cli" update apply >/dev/null

[[ $(<"$temporary_home/.local/state/omacos/installed-version") == "$(<"$project_root/VERSION")" ]]
[[ $(<"$temporary_home/.config/omacos/update-channel") == "stable" ]]
snapshot_id=$(OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$installed_cli" backup list | tail -1)
print 'post-update mutation' > "$temporary_home/.config/aerospace/aerospace.toml"
OMACOS_TEST_HOME="$temporary_home" OMACOS_TEST_MODE=true OMACOS_ROOT="$installed_root" \
  "$installed_cli" update rollback "$snapshot_id" >/dev/null
[[ $(<"$temporary_home/.config/aerospace/aerospace.toml") == "pre-update managed config" ]]

OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$installed_cli" uninstall --yes >/dev/null
print 'Update and rollback lifecycle test passed'
