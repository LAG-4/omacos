#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
installed_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
migration_directory=${OMACOS_MIGRATION_DIRECTORY:-$installed_root/migrations}
state_file="$omacos_home/.local/state/omacos/migrations.json"
mkdir -p "${state_file:h}"
[[ -f $state_file ]] || print -r -- '{"schemaVersion":1,"applied":[]}' > "$state_file"

run_migrations() {
  local migration
  local migration_id
  local temporary_state
  for migration in "$migration_directory"/*.zsh(N); do
    migration_id=${migration:t:r}
    if jq -e --arg id "$migration_id" '.applied | index($id) != null' "$state_file" >/dev/null; then
      continue
    fi
    OMACOS_ROOT="$installed_root" OMACOS_TEST_HOME="$omacos_home" /bin/zsh "$migration"
    temporary_state=$(mktemp "${state_file:h}/.migrations.XXXXXX")
    jq --arg id "$migration_id" '.applied += [$id]' "$state_file" > "$temporary_state"
    mv "$temporary_state" "$state_file"
    print "Applied migration $migration_id"
  done
}

case ${1:-run} in
  run) run_migrations ;;
  status) jq -c '.' "$state_file" ;;
  *) print -u2 'Usage: omacos migrate <run|status>'; exit 1 ;;
esac
