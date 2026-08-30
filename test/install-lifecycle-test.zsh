#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-lifecycle-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

mkdir -p "$temporary_home/.config/aerospace" "$temporary_home/.config/karabiner"
print "original shell config" > "$temporary_home/.zshrc"
print "original dot config" > "$temporary_home/.aerospace.toml"
print "original xdg config" > "$temporary_home/.config/aerospace/aerospace.toml"
cat > "$temporary_home/original-karabiner.json" <<'EOF'
{
  "profiles": [
    {
      "name": "User profile",
      "selected": true,
      "complex_modifications": {
        "rules": [
          {
            "description": "Keep this user rule",
            "manipulators": []
          }
        ]
      }
    }
  ]
}
EOF
cp "$temporary_home/original-karabiner.json" "$temporary_home/.config/karabiner/karabiner.json"
print "y" > "$temporary_home/installer-confirmation"

OMACOS_CONFIRMATION_DEVICE="$temporary_home/installer-confirmation" \
  OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_TEST_MODE=true \
  "$project_root/install.sh" </dev/null >/dev/null

if [[ ! -x $temporary_home/.local/bin/omacos-shell ]]; then
  print -u2 "Install lifecycle test failed: native shell was not installed"
  exit 1
fi

shell_app="$temporary_home/.local/share/omacos/OMacOSShell.app"
if [[ ! -x $shell_app/Contents/MacOS/omacos-shell ]]; then
  print -u2 "Install lifecycle test failed: native app bundle was not installed"
  exit 1
fi
if ! find "$shell_app/Contents/Resources" -maxdepth 1 \( -name '*.bundle' -o -name '*.resources' \) | grep -q .; then
  print -u2 "Install lifecycle test failed: Swift resource bundle was not copied into the app"
  exit 1
fi
if [[ $(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$shell_app/Contents/Info.plist") != *dictation* ]]; then
  print -u2 "Install lifecycle test failed: native app permission descriptions are missing"
  exit 1
fi
if [[ $(/usr/libexec/PlistBuddy -c 'Print :NSCameraUsageDescription' "$shell_app/Contents/Info.plist") != *camera* ]]; then
  print -u2 "Install lifecycle test failed: native camera permission description is missing"
  exit 1
fi
installed_entitlements="$temporary_home/installed-entitlements.plist"
codesign -d --entitlements "$installed_entitlements" --xml "$shell_app" 2>/dev/null
if ! plutil -p "$installed_entitlements" | rg -Fq '"com.apple.security.device.audio-input" => true'; then
  print -u2 "Install lifecycle test failed: audio input entitlement is missing"
  exit 1
fi
if ! plutil -p "$installed_entitlements" | rg -Fq '"com.apple.security.device.camera" => true'; then
  print -u2 "Install lifecycle test failed: camera entitlement is missing"
  exit 1
fi

if [[ ! -L $temporary_home/.local/bin/omacos ]]; then
  print -u2 "Install lifecycle test failed: CLI link was not installed"
  exit 1
fi

if ! jq -e '
  [.profiles[] | select(.selected == true) | .complex_modifications.rules[]?.description]
  | index("Use Right Option as the OMacOS Super layer") != null
' "$temporary_home/.config/karabiner/karabiner.json" >/dev/null; then
  print -u2 "Install lifecycle test failed: the OMacOS Super rule was installed but not enabled"
  exit 1
fi

if ! jq -e '
  [.profiles[] | .complex_modifications.rules[]?.description]
  | index("Keep this user rule") != null
' "$temporary_home/.config/karabiner/karabiner.json" >/dev/null; then
  print -u2 "Install lifecycle test failed: enabling OMacOS removed an existing Karabiner rule"
  exit 1
fi

if [[ -f $temporary_home/.aerospace.toml ]]; then
  print -u2 "Install lifecycle test failed: ambiguous dot AeroSpace config remains"
  exit 1
fi

installed_root="$temporary_home/.local/share/omacos/current"
OMACOS_TEST_HOME="$temporary_home" OMACOS_TEST_MODE=true "$installed_root/scripts/toggles.zsh" enable idle
mkdir -p "$temporary_home/test-bin"
cat > "$temporary_home/test-bin/aerospace" <<'EOF'
#!/bin/zsh
exit 0
EOF
chmod +x "$temporary_home/test-bin/aerospace"
ln -s "$temporary_home/test-bin/aerospace" "$temporary_home/test-bin/blueutil"
PATH="$temporary_home/test-bin:$PATH" OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" OMACOS_TEST_MODE=true "$temporary_home/.local/bin/omacos" doctor >/dev/null
OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$temporary_home/.local/bin/omacos" permissions status | jq -e '.schemaVersion == 1' >/dev/null
OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$temporary_home/.local/bin/omacos" uninstall --yes >/dev/null

if [[ $(<"$temporary_home/.aerospace.toml") != "original dot config" ]]; then
  print -u2 "Install lifecycle test failed: dot AeroSpace config was not restored"
  exit 1
fi

if [[ $(<"$temporary_home/.config/aerospace/aerospace.toml") != "original xdg config" ]]; then
  print -u2 "Install lifecycle test failed: XDG AeroSpace config was not restored"
  exit 1
fi

if [[ $(<"$temporary_home/.zshrc") != "original shell config" ]]; then
  print -u2 "Install lifecycle test failed: shell integration was not removed cleanly"
  exit 1
fi

if ! cmp -s "$temporary_home/original-karabiner.json" "$temporary_home/.config/karabiner/karabiner.json"; then
  print -u2 "Install lifecycle test failed: the original Karabiner profile was not restored"
  exit 1
fi

if [[ -e $temporary_home/.local/share/omacos/current || -e $temporary_home/.local/bin/omacos-shell ]]; then
  print -u2 "Install lifecycle test failed: installed files remain after uninstall"
  exit 1
fi

if [[ -e $temporary_home/Library/LaunchAgents/dev.omacos.stay-awake.plist ]]; then
  print -u2 "Install lifecycle test failed: stay-awake LaunchAgent remains after uninstall"
  exit 1
fi

print "Install and uninstall lifecycle test passed"
