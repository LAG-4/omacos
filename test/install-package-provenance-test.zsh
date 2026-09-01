#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-package-provenance-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

make_fake_brew() {
  local fake_brew=$1
  cat > "$fake_brew" <<'EOF'
#!/bin/zsh

set -euo pipefail

print -r -- "$*" >> "$OMACOS_FAKE_BREW_LOG"
formula_state="$OMACOS_FAKE_BREW_STATE/formulae"
cask_state="$OMACOS_FAKE_BREW_STATE/casks"
tap_state="$OMACOS_FAKE_BREW_STATE/taps"

case "${1:-}" in
  --version)
    print 'Homebrew 6.0.20'
    ;;
  trust)
    if [[ ${2:-} == '--json=v1' ]]; then
      print '{"taps":[],"formulae":[],"casks":[],"commands":[]}'
    fi
    ;;
  untrust)
    ;;
  tap)
    cat "$tap_state"
    ;;
  untap)
    /usr/bin/grep -vxF "${2:-}" "$tap_state" > "$tap_state.next" || true
    mv "$tap_state.next" "$tap_state"
    ;;
  list)
    if [[ ${2:-} == '--formula' ]]; then
      cat "$formula_state"
    elif [[ ${2:-} == '--cask' ]]; then
      cat "$cask_state"
    else
      exit 1
    fi
    ;;
  bundle)
    print 'git' > "$formula_state"
    print 'jq' >> "$formula_state"
    print 'felixkratz/formulae/borders' >> "$formula_state"
    print 'aerospace' > "$cask_state"
    print 'ghostty' >> "$cask_state"
    print 'karabiner-elements' >> "$cask_state"
    print 'nikitabobko/tap' > "$tap_state"
    print 'felixkratz/formulae' >> "$tap_state"
    ;;
  uninstall)
    kind=${2:-}
    package=${3:-}
    if [[ -n ${OMACOS_FAKE_BREW_FAIL_ONCE_PACKAGE:-} \
      && $package == "$OMACOS_FAKE_BREW_FAIL_ONCE_PACKAGE" \
      && ! -f $OMACOS_FAKE_BREW_STATE/failed-once ]]; then
      touch "$OMACOS_FAKE_BREW_STATE/failed-once"
      exit 1
    fi
    if [[ $kind == '--formula' ]]; then
      /usr/bin/grep -vxF "$package" "$formula_state" > "$formula_state.next" || true
      mv "$formula_state.next" "$formula_state"
    elif [[ $kind == '--cask' ]]; then
      /usr/bin/grep -vxF "$package" "$cask_state" > "$cask_state.next" || true
      mv "$cask_state.next" "$cask_state"
    else
      exit 1
    fi
    ;;
  *)
    print -u2 "Unexpected fake Homebrew command: $*"
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_brew"
}

run_install_cycle() {
  local cycle_name=$1
  local uninstall_packages=$2
  local cycle_directory="$temporary_directory/$cycle_name"
  local fake_home="$cycle_directory/home"
  local fake_brew="$cycle_directory/brew"
  local fake_brew_state="$cycle_directory/brew-state"
  local fake_brew_log="$cycle_directory/brew.log"

  mkdir -p "$fake_home" "$fake_brew_state"
  print 'git' > "$fake_brew_state/formulae"
  print 'aerospace' > "$fake_brew_state/casks"
  print 'ghostty' >> "$fake_brew_state/casks"
  print 'nikitabobko/tap' > "$fake_brew_state/taps"
  make_fake_brew "$fake_brew"

  OMACOS_BREW="$fake_brew" \
    OMACOS_FAKE_BREW_LOG="$fake_brew_log" \
    OMACOS_FAKE_BREW_STATE="$fake_brew_state" \
    OMACOS_TEST_HOME="$fake_home" \
    OMACOS_TEST_INSTALL_PACKAGES=true \
    OMACOS_TEST_MODE=true \
    "$project_root/install.sh" --yes >/dev/null

  provenance_directory="$fake_home/.local/state/omacos/package-provenance"
  [[ $(<"$provenance_directory/introduced-formulae.txt") == $'felixkratz/formulae/borders\njq' ]]
  [[ $(<"$provenance_directory/introduced-casks.txt") == 'karabiner-elements' ]]
  [[ $(<"$provenance_directory/introduced-taps.txt") == 'felixkratz/formulae' ]]

  uninstall_arguments=(uninstall --yes)
  if $uninstall_packages; then
    uninstall_arguments+=(--remove-packages)
  fi
  OMACOS_BREW="$fake_brew" \
    OMACOS_FAKE_BREW_FAIL_ONCE_PACKAGE="$($uninstall_packages && print jq || true)" \
    OMACOS_FAKE_BREW_LOG="$fake_brew_log" \
    OMACOS_FAKE_BREW_STATE="$fake_brew_state" \
    OMACOS_TEST_HOME="$fake_home" \
    OMACOS_TEST_MODE=true \
    "$fake_home/.local/bin/omacos" "${uninstall_arguments[@]}" >/dev/null

  /usr/bin/grep -qx 'aerospace' "$fake_brew_state/casks"
  /usr/bin/grep -qx 'ghostty' "$fake_brew_state/casks"
  /usr/bin/grep -qx 'git' "$fake_brew_state/formulae"

  if $uninstall_packages; then
    ! /usr/bin/grep -qx 'karabiner-elements' "$fake_brew_state/casks"
    ! /usr/bin/grep -qx 'jq' "$fake_brew_state/formulae"
    ! /usr/bin/grep -qx 'felixkratz/formulae/borders' "$fake_brew_state/formulae"
    [[ $(grep -c '^uninstall --formula jq$' "$fake_brew_log") == 2 ]]
  else
    /usr/bin/grep -qx 'karabiner-elements' "$fake_brew_state/casks"
    /usr/bin/grep -qx 'jq' "$fake_brew_state/formulae"
    ! rg -q '^uninstall ' "$fake_brew_log"
  fi
}

run_install_cycle keep-packages false
run_install_cycle remove-introduced-packages true

print 'Install package provenance and conservative uninstall tests passed'
