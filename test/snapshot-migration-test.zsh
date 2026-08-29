#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_home=$(mktemp -d -t omacos-snapshot-test.XXXXXX)
migration_directory=$(mktemp -d -t omacos-migration-test.XXXXXX)
trap 'rm -rf "$temporary_home" "$migration_directory"' EXIT

mkdir -p "$temporary_home/.config/omacos"
print 'before snapshot' > "$temporary_home/.config/omacos/example"
snapshot_id=$(OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/managed-snapshot.zsh" create test-snapshot)
[[ $snapshot_id == "test-snapshot" ]]
print 'after snapshot' > "$temporary_home/.config/omacos/example"
OMACOS_TEST_HOME="$temporary_home" "$project_root/scripts/managed-snapshot.zsh" restore test-snapshot >/dev/null
[[ $(<"$temporary_home/.config/omacos/example") == "before snapshot" ]]

cat > "$migration_directory/001-test.zsh" <<'EOF'
#!/bin/zsh
counter_file="$OMACOS_TEST_HOME/migration-counter"
counter=0
[[ -f $counter_file ]] && counter=$(<"$counter_file")
print "$(( counter + 1 ))" > "$counter_file"
EOF
chmod +x "$migration_directory/001-test.zsh"

OMACOS_TEST_HOME="$temporary_home" OMACOS_MIGRATION_DIRECTORY="$migration_directory" \
  "$project_root/scripts/migrations.zsh" run >/dev/null
OMACOS_TEST_HOME="$temporary_home" OMACOS_MIGRATION_DIRECTORY="$migration_directory" \
  "$project_root/scripts/migrations.zsh" run >/dev/null
[[ $(<"$temporary_home/migration-counter") == "1" ]]
jq -e '.applied == ["001-test"]' "$temporary_home/.local/state/omacos/migrations.json" >/dev/null

print 'Managed snapshot and migration tests passed'
