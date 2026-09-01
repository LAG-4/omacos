#!/bin/zsh

set -euo pipefail

source_archive=${1:-}
[[ -f $source_archive ]] || { print -u2 "Missing OMacOS source archive: $source_archive"; exit 2; }

test_root=/tmp/omacos-vm-lifecycle
source_root="$test_root/source"
baseline_root="$test_root/baseline"
rm -rf "$test_root"
mkdir -p "$source_root" "$baseline_root"
/usr/bin/tar -xzf "$source_archive" -C "$source_root"

if [[ ! -x /opt/homebrew/bin/brew ]]; then
  print "[guest 1/7] Installing Homebrew into the disposable VM..."
  NONINTERACTIVE=1 /bin/bash -c "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

print "[guest 2/7] Establishing pre-existing user applications..."
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask nikitabobko/tap/aerospace ghostty

print 'config-version = 2
start-at-login = false
auto-reload-config = true
gaps.inner.horizontal = 5
gaps.inner.vertical = 5
gaps.outer.left = 10
gaps.outer.bottom = 10
gaps.outer.top = 10
gaps.outer.right = 10
[mode.main.binding]' > "$HOME/.aerospace.toml"
/usr/bin/open -a AeroSpace
sleep 4
/usr/bin/osascript -e 'tell application "AeroSpace" to quit' >/dev/null 2>&1 || true
sleep 2

/usr/bin/shasum -a 256 "$HOME/.aerospace.toml" > "$baseline_root/aerospace.sha256"
brew list --formula --full-name | LC_ALL=C sort > "$baseline_root/formulae.txt"
brew list --cask --full-name | LC_ALL=C sort > "$baseline_root/casks.txt"
brew tap | LC_ALL=C sort > "$baseline_root/taps.txt"

print "[guest 3/7] Installing the current OMacOS checkout..."
OMACOS_INSTALL_CHANNEL=source "$source_root/install.sh" --yes

print "[guest 4/7] Exercising the installed command surface..."
set +e
"$HOME/.local/bin/omacos" doctor
doctor_status=$?
set -e
if (( doctor_status != 0 && doctor_status != 2 )); then
  print -u2 "Unexpected doctor status: $doctor_status"
  exit 1
fi
"$HOME/.local/bin/omacos" wm profile | grep -qx aerospace
"$HOME/.local/bin/omacos" parity summary >/dev/null
jq -e '.bar.horizontalSize == 26 and .menu.width == 300' \
  "$HOME/.local/share/omacos/current/Sources/OMacOSShell/Resources/omarchy-shell-contract.json" >/dev/null

print "[guest 5/7] Uninstalling OMacOS and only packages it introduced..."
"$HOME/.local/bin/omacos" uninstall --yes --remove-packages

print "[guest 6/7] Comparing the machine with its pre-install baseline..."
brew list --cask ghostty >/dev/null
brew list --cask aerospace >/dev/null
/usr/bin/shasum -a 256 -c "$baseline_root/aerospace.sha256"
[[ ! -e $HOME/.local/bin/omacos ]]
[[ ! -e $HOME/.local/bin/omacos-shell ]]
[[ ! -e $HOME/Library/LaunchAgents/dev.omacos.shell.plist ]]
[[ ! -e $HOME/.config/karabiner/assets/complex_modifications/omacos-super-key.json ]]

status=$(
  OMACOS_TEST_HOME="$HOME" OMACOS_ROOT="$source_root" \
    "$source_root/scripts/aerospace-lifecycle.zsh" status
)
grep -Fq 'process=stopped' <<< "$status"
if ! grep -Eq 'login-item=(disabled|unknown)' <<< "$status"; then
  print -u2 "AeroSpace login state was not restored: $status"
  exit 1
fi

print "[guest 7/7] Lifecycle baseline restored. Ghostty and AeroSpace were preserved."
