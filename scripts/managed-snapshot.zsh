#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
snapshot_root="$omacos_home/.local/state/omacos/snapshots"
mkdir -p "$snapshot_root"

managed_paths=(
  .local/share/omacos/current
  .local/share/omacos/OMacOSShell.app
  .local/bin/omacos
  .local/bin/omacos-shell
  .config/aerospace/aerospace.toml
  .config/karabiner/assets/complex_modifications/omacos-super-key.json
  .config/omacos
  .config/ghostty/themes/OMacOS
  Library/LaunchAgents/dev.omacos.shell.plist
  .zshrc
)

validate_snapshot_id() {
  local snapshot_id=$1
  local snapshot_pattern='^[A-Za-z0-9._-]+$'
  if [[ -z $snapshot_id || ! $snapshot_id =~ $snapshot_pattern ]]; then
    print -u2 'Snapshot ids may contain only letters, numbers, dots, underscores, and hyphens.'
    return 1
  fi
}

create_snapshot() {
  local snapshot_id=${1:-$(date +%Y%m%d-%H%M%S)}
  local snapshot_directory="$snapshot_root/$snapshot_id"
  validate_snapshot_id "$snapshot_id"
  if [[ -e $snapshot_directory ]]; then
    print -u2 "Snapshot already exists: $snapshot_id"
    return 1
  fi
  mkdir -p "$snapshot_directory/files"
  : > "$snapshot_directory/manifest"
  for relative_path in "${managed_paths[@]}"; do
    if [[ -e $omacos_home/$relative_path || -L $omacos_home/$relative_path ]]; then
      mkdir -p "$snapshot_directory/files/${relative_path:h}"
      cp -a "$omacos_home/$relative_path" "$snapshot_directory/files/$relative_path"
      print -r -- "$relative_path" >> "$snapshot_directory/manifest"
    fi
  done
  print -r -- "$snapshot_id" > "$snapshot_root/latest"
  print -r -- "$snapshot_id"
}

restore_snapshot() {
  local snapshot_id=${1:-}
  if [[ -z $snapshot_id && -f $snapshot_root/latest ]]; then
    snapshot_id=$(<"$snapshot_root/latest")
  fi
  validate_snapshot_id "$snapshot_id"
  local snapshot_directory="$snapshot_root/$snapshot_id"
  if [[ ! -f $snapshot_directory/manifest ]]; then
    print -u2 "Snapshot not found: $snapshot_id"
    return 1
  fi

  for relative_path in "${managed_paths[@]}"; do
    if [[ -e $omacos_home/$relative_path || -L $omacos_home/$relative_path ]]; then
      rm -rf "$omacos_home/$relative_path"
    fi
  done
  while IFS= read -r relative_path; do
    [[ -n $relative_path ]] || continue
    mkdir -p "$omacos_home/${relative_path:h}"
    cp -a "$snapshot_directory/files/$relative_path" "$omacos_home/$relative_path"
  done < "$snapshot_directory/manifest"
  print "Restored OMacOS snapshot $snapshot_id."
}

case ${1:-list} in
  create) create_snapshot "${2:-}" ;;
  restore) restore_snapshot "${2:-}" ;;
  list)
    for snapshot_directory in "$snapshot_root"/*(N/); do
      print -r -- "${snapshot_directory:t}"
    done
    ;;
  *) print -u2 'Usage: omacos backup <create [ID]|list|restore [ID]>'; exit 1 ;;
esac
