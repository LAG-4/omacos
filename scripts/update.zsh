#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
installed_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
test_mode=${OMACOS_TEST_MODE:-false}
curl_command=${OMACOS_CURL:-/usr/bin/curl}
version_file="$omacos_home/.local/state/omacos/installed-version"
channel_file="$omacos_home/.config/omacos/update-channel"
repository='https://github.com/LAG-4/omacos'
latest_release_api='https://api.github.com/repos/LAG-4/omacos/releases/latest'
releases_api='https://api.github.com/repos/LAG-4/omacos/releases?per_page=30'
update_directory=''

current_version() {
  if [[ -f $version_file ]]; then
    print -r -- "$(<"$version_file")"
  elif [[ -f $installed_root/VERSION ]]; then
    print -r -- "$(<"$installed_root/VERSION")"
  else
    print unknown
  fi
}

current_update_channel() {
  if [[ -f $channel_file ]]; then
    local channel
    channel=$(<"$channel_file")
    if [[ $channel == "stable" || $channel == "rc" || $channel == "edge" || $channel == "dev" ]]; then
      print -r -- "$channel"
      return
    fi
  fi
  print stable
}

latest_release_tag() {
  local channel=${1:-stable}
  local release_json_path="$update_directory/latest-release.json"
  local release_api=$latest_release_api
  [[ $channel == "rc" ]] && release_api=$releases_api
  "$curl_command" -fsSL "$release_api" -o "$release_json_path" || {
    print -u2 'No signed OMacOS release is currently available.'
    return 1
  }
  local tag
  if [[ $channel == "rc" ]]; then
    tag=$(jq -r 'first(.[] | select(.draft == false and .prerelease == true) | .tag_name) // empty' "$release_json_path")
  else
    tag=$(plutil -extract tag_name raw "$release_json_path" 2>/dev/null)
  fi
  [[ -n $tag ]] || {
    print -u2 'The latest OMacOS release metadata is invalid.'
    return 1
  }
  [[ $tag == v[0-9]* ]] || {
    print -u2 'The latest OMacOS release tag is invalid.'
    return 1
  }
  print -r -- "$tag"
}

stage_source_branch() {
  local destination=$1
  local branch=$2
  local source_root="$destination/omacos-source"
  mkdir -p "$source_root"
  if [[ -n ${OMACOS_UPDATE_SOURCE:-} ]]; then
    rsync -a --exclude .git --exclude .build "$OMACOS_UPDATE_SOURCE/" "$source_root/"
  else
    "$curl_command" -fsSL "$repository/archive/refs/heads/$branch.tar.gz" \
      | tar -xz --strip-components=1 -C "$source_root"
  fi
}

create_pre_update_snapshot() {
  local snapshot_id="pre-update-$(date +%Y%m%d-%H%M%S)"
  OMACOS_TEST_HOME="$omacos_home" "$installed_root/scripts/managed-snapshot.zsh" create "$snapshot_id" >/dev/null
  print -r -- "$snapshot_id"
}

apply_source_update() {
  local selected_channel=$1
  local branch=$2
  local source_root="$update_directory/omacos-source"
  stage_source_branch "$update_directory" "$branch"
  [[ -x $source_root/install.sh ]] || {
    print -u2 'Downloaded update does not contain an installer.'
    return 1
  }

  OMACOS_TEST_HOME="$omacos_home" OMACOS_TEST_MODE="$test_mode" \
    OMACOS_SELECTED_CHANNEL="$selected_channel" "$source_root/install.sh" --yes
}

apply_release_update() {
  local tag=$1
  local selected_channel=$2
  local bootstrap_path="$update_directory/install-$tag.zsh"
  "$curl_command" -fsSL "https://raw.githubusercontent.com/LAG-4/omacos/$tag/install.sh" -o "$bootstrap_path"
  OMACOS_TEST_HOME="$omacos_home" OMACOS_TEST_MODE="$test_mode" OMACOS_CURL="$curl_command" \
    OMACOS_INSTALL_CHANNEL=release OMACOS_RELEASE_TAG="$tag" OMACOS_SELECTED_CHANNEL="$selected_channel" \
    /bin/zsh "$bootstrap_path" --yes
}

apply_update() {
  update_directory=$(mktemp -d -t omacos-update.XXXXXX)
  trap 'rm -rf "$update_directory"' EXIT
  local channel
  channel=$(current_update_channel)
  local release_tag=''
  if [[ -z ${OMACOS_UPDATE_SOURCE:-} && ($channel == "stable" || $channel == "rc") ]]; then
    release_tag=$(latest_release_tag "$channel")
  fi

  local snapshot_id
  snapshot_id=$(create_pre_update_snapshot)
  if [[ -n ${OMACOS_UPDATE_SOURCE:-} ]]; then
    apply_source_update "$channel" main
  elif [[ $channel == "stable" || $channel == "rc" ]]; then
    apply_release_update "$release_tag" "$channel"
  elif [[ $channel == "dev" ]]; then
    apply_source_update dev dev
  else
    apply_source_update edge main
  fi

  print "OMacOS updated to $(current_version) on $channel. Roll back with: omacos update rollback $snapshot_id"
}

check_update() {
  update_directory=$(mktemp -d -t omacos-update-check.XXXXXX)
  trap 'rm -rf "$update_directory"' EXIT
  local channel
  channel=$(current_update_channel)
  if [[ -n ${OMACOS_UPDATE_SOURCE:-} ]]; then
    print "Available OMacOS version: $(<"$OMACOS_UPDATE_SOURCE/VERSION") (local test source)"
  elif [[ $channel == "stable" ]]; then
    local tag
    tag=$(latest_release_tag stable)
    print "Available OMacOS version: ${tag#v} (stable)"
  elif [[ $channel == "rc" ]]; then
    local tag
    tag=$(latest_release_tag rc)
    print "Available OMacOS version: ${tag#v} (rc)"
  elif [[ $channel == "dev" ]]; then
    print 'The dev channel tracks the public dev branch. Run `omacos update apply` to install it.'
  else
    print 'The edge channel tracks the current public main branch. Run `omacos update apply` to install it.'
  fi
}

case ${1:-status} in
  status)
    print "Installed OMacOS version: $(current_version)"
    print "Update channel: $(current_update_channel)"
    ;;
  check)
    check_update
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
