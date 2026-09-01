#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
brew_command=${OMACOS_BREW:-brew}
provenance_directory="$omacos_home/.local/state/omacos/package-provenance"

brew_is_available() {
  if [[ $brew_command == */* ]]; then
    [[ -x $brew_command ]]
  else
    command -v "$brew_command" >/dev/null 2>&1
  fi
}

capture_brew_lines() {
  local output_file=$1
  shift
  if brew_is_available; then
    "$brew_command" "$@" 2>/dev/null | LC_ALL=C /usr/bin/sort -u > "$output_file"
  else
    : > "$output_file"
  fi
}

capture_package_snapshot() {
  local phase=$1
  mkdir -p "$provenance_directory"
  capture_brew_lines "$provenance_directory/$phase-formulae.txt" list --formula --full-name
  capture_brew_lines "$provenance_directory/$phase-casks.txt" list --cask --full-name
  capture_brew_lines "$provenance_directory/$phase-taps.txt" tap
}

record_introduced_packages() {
  local category
  for category in formulae casks taps; do
    /usr/bin/comm -13 \
      "$provenance_directory/before-$category.txt" \
      "$provenance_directory/after-$category.txt" \
      > "$provenance_directory/introduced-$category.txt"
  done
}

print_package_file() {
  local label=$1
  local package_file=$2
  [[ -s $package_file ]] || return 0
  print "$label"
  while IFS= read -r package; do
    [[ -n $package ]] && print "  $package"
  done < "$package_file"
}

report_retained_packages() {
  [[ -d $provenance_directory ]] || return 0
  if [[ ! -s $provenance_directory/introduced-formulae.txt \
    && ! -s $provenance_directory/introduced-casks.txt \
    && ! -s $provenance_directory/introduced-taps.txt ]]; then
    print "OMacOS did not introduce any Homebrew packages."
    return 0
  fi
  print "Homebrew packages introduced by OMacOS are being kept."
  print_package_file "Formulae" "$provenance_directory/introduced-formulae.txt"
  print_package_file "Applications" "$provenance_directory/introduced-casks.txt"
  print_package_file "Taps" "$provenance_directory/introduced-taps.txt"
}

remove_introduced_packages() {
  [[ -d $provenance_directory ]] || {
    print "No OMacOS package-provenance record exists; no Homebrew packages were removed."
    return 0
  }
  brew_is_available || {
    print -u2 "Homebrew is unavailable; OMacOS cannot remove the packages it introduced."
    return 1
  }

  local package
  local cleanup_directory
  cleanup_directory=$(mktemp -d -t omacos-package-cleanup.XXXXXX)
  trap "rm -rf ${(q)cleanup_directory}" EXIT

  local retained_casks="$cleanup_directory/retained-casks.txt"
  local retained_formulae="$cleanup_directory/retained-formulae.txt"
  local retained_taps="$cleanup_directory/retained-taps.txt"
  : > "$retained_casks"
  : > "$retained_formulae"
  : > "$retained_taps"

  while IFS= read -r package; do
    [[ -n $package ]] || continue
    if "$brew_command" list --cask "$package" >/dev/null 2>&1; then
      print "Removing OMacOS-introduced application: $package"
      if ! "$brew_command" uninstall --cask "$package"; then
        print -u2 "Keeping $package because Homebrew could not remove it safely."
        print -r -- "$package" >> "$retained_casks"
      fi
    fi
  done < "$provenance_directory/introduced-casks.txt"

  # Homebrew may list a requested formula before another introduced formula
  # that depends on it. Retry the retained set so dependency order never turns
  # a conservative uninstall into an abrupt partial failure.
  cp "$provenance_directory/introduced-formulae.txt" "$cleanup_directory/formulae-pending.txt"
  local pass progress
  for pass in {1..4}; do
    progress=false
    : > "$cleanup_directory/formulae-next.txt"
    while IFS= read -r package; do
      [[ -n $package ]] || continue
      if ! "$brew_command" list --formula "$package" >/dev/null 2>&1; then
        continue
      fi
      print "Removing OMacOS-introduced formula: $package"
      if "$brew_command" uninstall --formula "$package"; then
        progress=true
      else
        print -r -- "$package" >> "$cleanup_directory/formulae-next.txt"
      fi
    done < "$cleanup_directory/formulae-pending.txt"
    mv "$cleanup_directory/formulae-next.txt" "$cleanup_directory/formulae-pending.txt"
    [[ -s $cleanup_directory/formulae-pending.txt ]] || break
    $progress || break
  done
  cp "$cleanup_directory/formulae-pending.txt" "$retained_formulae"

  while IFS= read -r package; do
    [[ -n $package ]] || continue
    if "$brew_command" tap | /usr/bin/grep -qxF "$package"; then
      print "Removing OMacOS-introduced tap: $package"
      if ! "$brew_command" untap "$package"; then
        print -u2 "Keeping tap $package because Homebrew still needs it."
        print -r -- "$package" >> "$retained_taps"
      fi
    fi
  done < "$provenance_directory/introduced-taps.txt"

  if [[ -s $retained_casks || -s $retained_formulae || -s $retained_taps ]]; then
    print "Some OMacOS-introduced packages were retained because Homebrew could not remove them safely."
    print_package_file "Applications" "$retained_casks"
    print_package_file "Formulae" "$retained_formulae"
    print_package_file "Taps" "$retained_taps"
  fi
}

case ${1:-} in
  capture-before)
    mkdir -p "$provenance_directory"
    if brew_is_available; then
      print true > "$provenance_directory/homebrew-was-present.txt"
    else
      print false > "$provenance_directory/homebrew-was-present.txt"
    fi
    capture_package_snapshot before
    ;;
  capture-after)
    capture_package_snapshot after
    record_introduced_packages
    ;;
  report-retained)
    report_retained_packages
    ;;
  remove-introduced)
    remove_introduced_packages
    ;;
  *)
    print -u2 "Usage: package-provenance.zsh <capture-before|capture-after|report-retained|remove-introduced>"
    exit 1
    ;;
esac
