#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-package-trust-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

fake_brew="$temporary_directory/brew"
brew_log="$temporary_directory/brew.log"
trust_state="$temporary_directory/trusted"
fail_once_state="$temporary_directory/failed-once"

cat > "$fake_brew" <<'EOF'
#!/bin/zsh

set -euo pipefail

print -r -- "$*" >> "$OMACOS_FAKE_BREW_LOG"

if [[ ${1:-} == "trust" && ${2:-} == "--json=v1" ]]; then
  if [[ -f $OMACOS_FAKE_BREW_TRUST_STATE ]]; then
    print '{"taps":[],"formulae":["felixkratz/formulae/borders"],"casks":[],"commands":[]}'
  else
    print '{"taps":[],"formulae":[],"casks":[],"commands":[]}'
  fi
  exit 0
fi

if [[ ${1:-} == "list" || ${1:-} == "tap" ]]; then
  exit 0
fi

if [[ ${1:-} == "trust" && ${2:-} == "--formula" && ${3:-} == "felixkratz/formulae/borders" ]]; then
  touch "$OMACOS_FAKE_BREW_TRUST_STATE"
  exit 0
fi

if [[ ${1:-} == "untrust" && ${2:-} == "--formula" && ${3:-} == "felixkratz/formulae/borders" ]]; then
  rm -f "$OMACOS_FAKE_BREW_TRUST_STATE"
  exit 0
fi

if [[ ${1:-} == "bundle" ]]; then
  if [[ ! -f $OMACOS_FAKE_BREW_TRUST_STATE ]]; then
    print -u2 "Error: Refusing to load formula felixkratz/formulae/borders from untrusted tap felixkratz/formulae."
    exit 1
  fi
  if [[ -n ${OMACOS_FAKE_BREW_FAIL_ONCE_STATE:-} && ! -f $OMACOS_FAKE_BREW_FAIL_ONCE_STATE ]]; then
    touch "$OMACOS_FAKE_BREW_FAIL_ONCE_STATE"
    print -u2 "Error: simulated partial Homebrew bundle failure"
    exit 1
  fi
  exit 0
fi

print -u2 "Unexpected fake Homebrew command: $*"
exit 1
EOF
chmod +x "$fake_brew"

set +e
failed_installer_output=$(
  OMACOS_BREW="$fake_brew" \
    OMACOS_FAKE_BREW_LOG="$brew_log" \
    OMACOS_FAKE_BREW_FAIL_ONCE_STATE="$fail_once_state" \
    OMACOS_FAKE_BREW_TRUST_STATE="$trust_state" \
    OMACOS_TEST_HOME="$temporary_directory/home" \
    OMACOS_TEST_INSTALL_PACKAGES=true \
    OMACOS_TEST_MODE=true \
    "$project_root/install.sh" --yes 2>&1
)
failed_installer_status=$?
set -e

if (( failed_installer_status == 0 )) \
  || [[ $failed_installer_output != *"simulated partial Homebrew bundle failure"* ]] \
  || [[ $failed_installer_output != *"stopped during step 2/8: Installing the Homebrew package bundle"* ]] \
  || [[ $failed_installer_output != *"safe to run the same install command again"* ]]; then
  print -u2 "Installer package trust test failed: a partial bundle failure did not name the stage and retry path"
  print -u2 "$failed_installer_output"
  exit 1
fi

if [[ -f $trust_state ]]; then
  print -u2 "Installer package trust test failed: temporary formula trust remained after a bundle failure"
  exit 1
fi

set +e
installer_output=$(
  OMACOS_BREW="$fake_brew" \
    OMACOS_FAKE_BREW_LOG="$brew_log" \
    OMACOS_FAKE_BREW_FAIL_ONCE_STATE="$fail_once_state" \
    OMACOS_FAKE_BREW_TRUST_STATE="$trust_state" \
    OMACOS_TEST_HOME="$temporary_directory/home" \
    OMACOS_TEST_INSTALL_PACKAGES=true \
    OMACOS_TEST_MODE=true \
    "$project_root/install.sh" --yes 2>&1
)
installer_status=$?
set -e

if (( installer_status != 0 )); then
  print -u2 "Installer package resume test failed with status $installer_status"
  print -u2 "$installer_output"
  exit 1
fi

if [[ $installer_output != *"[1/8] Preparing Homebrew..."* \
  || $installer_output != *"[8/8] Done"* \
  || $installer_output != *"OMacOS installed."* ]]; then
  print -u2 "Installer progress test failed: the resumed install did not report all numbered stages"
  exit 1
fi

if (( $(rg -c '^trust --formula felixkratz/formulae/borders$' "$brew_log") != 2 )) \
  || (( $(rg -c '^untrust --formula felixkratz/formulae/borders$' "$brew_log") != 2 )) \
  || (( $(rg -c '^bundle install --no-upgrade --file ' "$brew_log") != 2 )); then
  print -u2 "Installer package trust test failed: trust, bundle, and cleanup did not run once per attempt"
  print -u2 "$(<$brew_log)"
  exit 1
fi

if [[ -f $trust_state ]]; then
  print -u2 "Installer package trust test failed: temporary formula trust remained after success"
  exit 1
fi

print "Installer package trust, progress, failure, and partial-resume test passed"
