#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
installed_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
test_mode=${OMACOS_TEST_MODE:-false}
curl_command=${OMACOS_CURL:-/usr/bin/curl}
version_file="$omacos_home/.local/state/omacos/installed-version"
repository_archive='https://github.com/LAG-4/omacos/archive/refs/heads/main.tar.gz'
update_directory=''

current_version() {
  if [[ -f $version_file ]]; then
    print -r -- "$(<$version_file)"
  elif [[ -f $installed_root/VERSION ]]; then
    print -r -- "$(<$installed_root/VERSION)"
  else
    print 'unknown'
  fi
}

stage_update_source() {
  local destination=$1
  if [[ -n ${OMACOS_UPDATE_SOURCE:-} ]]; then
    mkdir -p "$destination/omacos-main"
    rsync -a --exclude .git --exclude .build "$OMACOS_UPDATE_SOURCE/" "$destination/omacos-main/"
  else
    "$curl_command" -fsSL "$repository_archive" | tar -xz -C "$destination"
  fi
}

apply_update() {
  local snapshot_id
  local source_root
  update_directory=$(mktemp -d -t omacos-update.XXXXXX)
  trap 'rm -rf "$update_directory"' EXIT
  stage_update_source "$update_directory"
  source_root="$update_directory/omacos-main"
  [[ -x $source_root/install.sh ]] || { print -u2 'Downloaded update does not contain an installer.'; return 1; }

  snapshot_id="pre-update-$(date +%Y%m%d-%H%M%S)"
  OMACOS_TEST_HOME="$omacos_home" "$installed_root/scripts/managed-snapshot.zsh" create "$snapshot_id" >/dev/null
  OMACOS_TEST_HOME="$omacos_home" OMACOS_TEST_MODE="$test_mode" "$source_root/install.sh" --yes
  mkdir -p "${version_file:h}"
  print -r -- "$(<$source_root/VERSION)" > "$version_file"
  print "OMacOS updated to $(<$source_root/VERSION). Roll back with: omacos update rollback $snapshot_id"
}

case ${1:-status} in
  status)
    print "Installed OMacOS version: $(current_version)"
    ;;
  check)
    if [[ -n ${OMACOS_UPDATE_SOURCE:-} ]]; then
      print "Available OMacOS version: $(<$OMACOS_UPDATE_SOURCE/VERSION)"
    else
      print 'Update checks track the public main branch. Run `omacos update apply` to install it.'
    fi
    ;;
  apply)
    apply_update
    ;;
  rollback)
    "$installed_root/scripts/managed-snapshot.zsh" restore "${2:-}"
    if ! $test_mode; then
      "$omacos_home/.local/bin/omacos" shell restart
    fi
    ;;
  *) print -u2 'Usage: omacos update <status|check|apply|rollback [SNAPSHOT]>'; exit 1 ;;
esac
