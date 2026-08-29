#!/bin/zsh

set -euo pipefail

omacos_repository="https://github.com/LAG-4/omacos"
curl_command=${OMACOS_CURL:-/usr/bin/curl}
install_channel=${OMACOS_INSTALL_CHANNEL:-auto}
requested_release_tag=${OMACOS_RELEASE_TAG:-}
script_path=${(%):-%N}
script_directory=${script_path:A:h}

if [[ ! -f $script_directory/Package.swift ]]; then
  bootstrap_directory=$(mktemp -d -t omacos-bootstrap.XXXXXX)
  trap 'rm -rf "$bootstrap_directory"' EXIT
  if [[ $install_channel != "auto" && $install_channel != "release" && $install_channel != "source" ]]; then
    print -u2 "Unknown OMacOS install channel: $install_channel"
    exit 1
  fi
  release_valid=false

  bootstrap_release() {
    local release_json_path tag version archive_name archive_url checksum_url source_url source_root prebuilt_app
    if [[ -n $requested_release_tag ]]; then
      tag=$requested_release_tag
    else
      release_json_path="$bootstrap_directory/latest-release.json"
      $curl_command -fsSL 'https://api.github.com/repos/LAG-4/omacos/releases/latest' -o "$release_json_path" || return 1
      tag=$(plutil -extract tag_name raw "$release_json_path" 2>/dev/null) || return 1
    fi
    [[ $tag == v[0-9]* ]] || return 1
    [[ -n $tag ]] || return 1
    version=${tag#v}
    archive_name="OMacOS-$version-arm64.zip"
    archive_url="$omacos_repository/releases/download/$tag/$archive_name"
    checksum_url="$archive_url.sha256"

    print "Downloading signed OMacOS release $tag..."
    $curl_command -fsSL "$archive_url" -o "$bootstrap_directory/$archive_name" || return 1
    $curl_command -fsSL "$checksum_url" -o "$bootstrap_directory/$archive_name.sha256" || return 1
    (cd "$bootstrap_directory" && shasum -a 256 -c "$archive_name.sha256") || return 1
    mkdir -p "$bootstrap_directory/release-app"
    ditto -x -k "$bootstrap_directory/$archive_name" "$bootstrap_directory/release-app" || return 1
    prebuilt_app="$bootstrap_directory/release-app/OMacOSShell.app"
    [[ -x $prebuilt_app/Contents/MacOS/omacos-shell ]] || return 1
    [[ $(plutil -extract CFBundleIdentifier raw "$prebuilt_app/Contents/Info.plist") == "dev.omacos.shell" ]] || return 1
    codesign --verify --deep --strict "$prebuilt_app" || return 1
    if [[ ${OMACOS_TEST_MODE:-false} != "true" ]]; then
      spctl --assess --type execute --verbose "$prebuilt_app" || return 1
    fi

    source_url="$omacos_repository/archive/refs/tags/$tag.tar.gz"
    $curl_command -fsSL "$source_url" | tar -xz -C "$bootstrap_directory" || return 1
    source_root=$(find "$bootstrap_directory" -maxdepth 1 -type d -name 'omacos-*' ! -name 'omacos-bootstrap*' -print -quit)
    [[ -n $source_root && -x $source_root/install.sh ]] || return 1
    release_valid=true
    OMACOS_SOURCE_ROOT="$source_root" OMACOS_PREBUILT_SHELL_APP="$prebuilt_app" \
      OMACOS_SELECTED_CHANNEL=stable "$source_root/install.sh" "$@"
  }

  if [[ $install_channel != "source" ]]; then
    if bootstrap_release "$@"; then
      exit 0
    else
      release_status=$?
      if $release_valid; then
        exit "$release_status"
      elif [[ $install_channel == "release" ]]; then
        print -u2 "No valid signed OMacOS release is available."
        exit 1
      fi
    fi
  fi

  print "Downloading the current OMacOS installer source..."
  $curl_command -fsSL "$omacos_repository/archive/refs/heads/main.tar.gz" | tar -xz -C "$bootstrap_directory"
  selected_source_channel=stable
  if [[ $install_channel == "source" ]]; then
    selected_source_channel=edge
  fi
  OMACOS_SOURCE_ROOT="$bootstrap_directory/omacos-main" OMACOS_SELECTED_CHANNEL="$selected_source_channel" \
    "$bootstrap_directory/omacos-main/install.sh" "$@"
  exit $?
fi

source_root=${OMACOS_SOURCE_ROOT:-$script_directory}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
dry_run=false
assume_yes=false
test_mode=${OMACOS_TEST_MODE:-false}
prebuilt_shell_app=${OMACOS_PREBUILT_SHELL_APP:-}
selected_channel=${OMACOS_SELECTED_CHANNEL:-stable}
confirmation_device=${OMACOS_CONFIRMATION_DEVICE:-/dev/tty}

if [[ $selected_channel != "stable" && $selected_channel != "edge" ]]; then
  print -u2 "Unknown OMacOS update channel: $selected_channel"
  exit 1
fi

read_installer_confirmation() {
  if [[ ! -r $confirmation_device ]]; then
    print -u2 "OMacOS confirmation failed: no interactive terminal is available. Re-run with --yes for a non-interactive installation."
    return 2
  fi

  if ! read -r answer < "$confirmation_device"; then
    print -u2 "OMacOS confirmation failed: could not read an answer from $confirmation_device"
    return 2
  fi

  [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
}

for argument in "$@"; do
  case $argument in
    --dry-run)
      dry_run=true
      ;;
    --yes|-y)
      assume_yes=true
      ;;
    --help|-h)
      cat <<'EOF'
Usage: install.sh [--dry-run] [--yes]

  --dry-run  Print checks and planned changes without writing anything
  --yes      Skip the interactive confirmation
EOF
      exit 0
      ;;
    *)
      print -u2 "Unknown installer option: $argument"
      exit 1
      ;;
  esac
done

if [[ $(uname -s) != "Darwin" ]]; then
  print -u2 "OMacOS only runs on macOS."
  exit 1
fi

if [[ $(uname -m) != "arm64" ]]; then
  print -u2 "OMacOS currently supports Apple Silicon Macs only."
  exit 1
fi

macos_major=$(sw_vers -productVersion | cut -d. -f1)
if (( macos_major < 26 )); then
  print -u2 "OMacOS requires macOS 26 or newer. This Mac runs macOS $macos_major."
  exit 1
fi

cat <<EOF
OMacOS installation plan

System
  Apple Silicon, macOS $(sw_vers -productVersion)

Packages
  AeroSpace, Karabiner-Elements, Ghostty, JankyBorders
  Omarchy-style developer tools including Neovim, tmux, fzf, ripgrep, fd, bat, eza, zoxide, mise, btop, yazi, ffmpeg, and GitHub CLI

Files
  $omacos_home/.local/share/omacos/current
  $omacos_home/.local/share/omacos/OMacOSShell.app
  $omacos_home/.local/bin/omacos
  $omacos_home/.local/bin/omacos-shell
  $omacos_home/.config/aerospace/aerospace.toml
  $omacos_home/.config/karabiner/assets/complex_modifications/omacos-super-key.json
  $omacos_home/.config/omacos
  one marked, reversible source block in $omacos_home/.zshrc
  $omacos_home/Library/LaunchAgents/dev.omacos.shell.plist

Existing AeroSpace configuration will be backed up before replacement.
macOS will ask you to approve Accessibility for AeroSpace and input monitoring for Karabiner-Elements.
Clipboard paste automation needs Accessibility for the OMacOS shell. Capture and OCR need Screen Recording when first used.
Dictation asks for Microphone and Speech Recognition access only when first invoked.
System Integrity Protection stays enabled.
EOF

if $dry_run; then
  print "\nDry run complete. No files or packages were changed."
  exit 0
fi

if ! $assume_yes; then
  print -n "\nContinue? [y/N] "
  if read_installer_confirmation; then
    :
  else
    confirmation_status=$?
    if (( confirmation_status == 1 )); then
      print "Installation cancelled."
      exit 0
    else
      exit "$confirmation_status"
    fi
  fi
fi

if ! $test_mode && ! command -v brew >/dev/null 2>&1; then
  print "Installing Homebrew with its official installer..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! $test_mode; then
  print "Installing OMacOS package dependencies..."
  brew bundle --file "$source_root/Brewfile"
fi

state_directory="$omacos_home/.local/state/omacos"
backup_directory="$state_directory/backups"
install_directory="$omacos_home/.local/share/omacos/current"
binary_directory="$omacos_home/.local/bin"
shell_app="$omacos_home/.local/share/omacos/OMacOSShell.app"
aerospace_directory="$omacos_home/.config/aerospace"
karabiner_rule_directory="$omacos_home/.config/karabiner/assets/complex_modifications"
launch_agent_directory="$omacos_home/Library/LaunchAgents"

mkdir -p "$backup_directory" "$binary_directory" "$aerospace_directory" "$karabiner_rule_directory" "$launch_agent_directory"

if [[ ! -f $state_directory/backup-recorded ]]; then
  if [[ -f $omacos_home/.aerospace.toml ]]; then
    cp "$omacos_home/.aerospace.toml" "$backup_directory/dot-aerospace.toml"
    touch "$state_directory/had-dot-aerospace-config"
  fi
  if [[ -f $aerospace_directory/aerospace.toml ]]; then
    cp "$aerospace_directory/aerospace.toml" "$backup_directory/xdg-aerospace.toml"
    touch "$state_directory/had-xdg-aerospace-config"
  fi
  touch "$state_directory/backup-recorded"
fi

if [[ -n $prebuilt_shell_app ]]; then
  [[ -x $prebuilt_shell_app/Contents/MacOS/omacos-shell ]] || { print -u2 "Prebuilt OMacOS shell is invalid: $prebuilt_shell_app"; exit 1; }
  print "Installing the signed native OMacOS shell..."
else
  print "Building the native OMacOS shell..."
  swift build --package-path "$source_root" -c release
fi

staging_directory=$(mktemp -d -t omacos-install.XXXXXX)
trap 'rm -rf "$staging_directory"' EXIT
mkdir -p "$staging_directory/current"
rsync -a --exclude .git --exclude .build "$source_root/" "$staging_directory/current/"

if [[ -e $install_directory ]]; then
  rm -rf "$install_directory"
fi
mkdir -p "${install_directory:h}"
mv "$staging_directory/current" "$install_directory"

rm -rf "$shell_app"
if [[ -n $prebuilt_shell_app ]]; then
  ditto "$prebuilt_shell_app" "$shell_app"
  codesign --verify --deep --strict "$shell_app"
else
  mkdir -p "$shell_app/Contents/MacOS" "$shell_app/Contents/Resources"
  cp "$source_root/.build/release/omacos-shell" "$shell_app/Contents/MacOS/omacos-shell"
  cp "$source_root/app/Info.plist" "$shell_app/Contents/Info.plist"
  resource_bundles=("$source_root"/.build/release/*.bundle(N) "$source_root"/.build/release/*.resources(N))
  if (( ${#resource_bundles[@]} > 0 )); then
    cp -R "$resource_bundles[1]" "$shell_app/Contents/Resources/"
  fi
  chmod +x "$shell_app/Contents/MacOS/omacos-shell"
  codesign --force --deep --options runtime --timestamp=none \
    --entitlements "$source_root/app/OMacOSShell.entitlements" --sign - "$shell_app" >/dev/null
fi
cat > "$binary_directory/omacos-shell" <<EOF
#!/bin/zsh
exec "$shell_app/Contents/MacOS/omacos-shell" "\$@"
EOF
chmod +x "$binary_directory/omacos-shell"
ln -sfn "$install_directory/bin/omacos" "$binary_directory/omacos"

rm -f "$omacos_home/.aerospace.toml"
cp "$install_directory/config/aerospace/aerospace.toml" "$aerospace_directory/aerospace.toml"
"$install_directory/scripts/generate-karabiner-config.zsh" \
  "$install_directory/config/keybindings.json" \
  "$karabiner_rule_directory/omacos-super-key.json"

OMACOS_ROOT="$install_directory" "$install_directory/scripts/render-theme.zsh" tokyo-night
mkdir -p "$omacos_home/.config/omacos"
print -r -- "$selected_channel" > "$omacos_home/.config/omacos/update-channel"
OMACOS_ROOT="$install_directory" "$install_directory/scripts/defaults.zsh" init >/dev/null
OMACOS_ROOT="$install_directory" "$install_directory/scripts/window-manager.zsh" init
OMACOS_ROOT="$install_directory" "$install_directory/scripts/shell-integration.zsh" install
OMACOS_ROOT="$install_directory" "$install_directory/scripts/migrations.zsh" run
print -r -- "$(<$install_directory/VERSION)" > "$state_directory/installed-version"

cat > "$launch_agent_directory/dev.omacos.shell.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.omacos.shell</string>
  <key>ProgramArguments</key>
  <array>
    <string>$shell_app/Contents/MacOS/omacos-shell</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$state_directory/shell.log</string>
  <key>StandardErrorPath</key>
  <string>$state_directory/shell-error.log</string>
</dict>
</plist>
EOF

launch_agent="$launch_agent_directory/dev.omacos.shell.plist"
if ! $test_mode; then
  launchctl bootout "gui/$UID" "$launch_agent" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID" "$launch_agent"

  if pgrep -x AeroSpace >/dev/null 2>&1; then
    aerospace reload-config || true
  else
    open -a AeroSpace
  fi

  open -a Karabiner-Elements
fi

cat <<'EOF'

OMacOS installed.

One manual step remains:
  Open Karabiner-Elements > Complex Modifications > Add predefined rule,
  then enable "Use Right Option as the OMacOS Super layer".

Run `omacos doctor` after approving the requested macOS permissions.
EOF
