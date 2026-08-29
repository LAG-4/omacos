#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_directory=$(mktemp -d -t omacos-menu-tools-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT
fake_bin="$temporary_directory/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/omacos" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_FAKE_CLI_LOG"
EOF
cat > "$fake_bin/open" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_FAKE_OPEN_LOG"
EOF
cat > "$fake_bin/osascript" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_FAKE_OSASCRIPT_LOG"
if [[ $* == *"Choose media"* ]]; then
  print "$OMACOS_FAKE_MEDIA_INPUT"
elif [[ $* == *"Output format"* ]]; then
  print "webp"
elif [[ $* == *"Choose a file"* ]]; then
  print "$OMACOS_FAKE_SHARE_INPUT"
fi
EOF
cat > "$fake_bin/magick" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_FAKE_TRANSCODE_LOG"
touch "${@[-1]}"
EOF
cat > "$fake_bin/ffmpeg" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_FAKE_TRANSCODE_LOG"
touch "${@[-1]}"
EOF
cat > "$fake_bin/brew" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_FAKE_BREW_LOG"
if [[ ${1:-} == "list" ]]; then
  exit 1
fi
EOF
cat > "$fake_bin/pbpaste" <<'EOF'
#!/bin/zsh
print "clipboard text"
EOF
chmod +x "$fake_bin"/*

export OMACOS_TEST_HOME="$temporary_directory/home"
export OMACOS_CLI="$fake_bin/omacos"
export OMACOS_OPEN_BINARY="$fake_bin/open"
export OMACOS_OSASCRIPT="$fake_bin/osascript"
export OMACOS_FAKE_CLI_LOG="$temporary_directory/cli.log"
export OMACOS_FAKE_OPEN_LOG="$temporary_directory/open.log"
export OMACOS_FAKE_OSASCRIPT_LOG="$temporary_directory/osascript.log"

"$project_root/scripts/menu.zsh" run learn.keybindings
"$project_root/scripts/menu.zsh" run trigger.toggle.idle-lock
"$project_root/scripts/menu.zsh" run style.font
"$project_root/scripts/menu.zsh" run update.channel.stable
"$project_root/scripts/menu.zsh" run update.channel.edge
rg -Fq 'shell toggle-panel keybindings' "$temporary_directory/cli.log"
rg -Fq 'toggle toggle idle' "$temporary_directory/cli.log"
rg -Fq 'channel set stable' "$temporary_directory/cli.log"
rg -Fq 'channel set edge' "$temporary_directory/cli.log"
rg -Fq -- '-a Font Book' "$temporary_directory/open.log"

set +e
unsupported_output=$("$project_root/scripts/menu.zsh" run system.hibernate)
unsupported_status=$?
set -e
(( unsupported_status == 2 ))
[[ $unsupported_output == *"macOS owns hibernation"* ]]

media_input="$temporary_directory/demo.png"
touch "$media_input"
export OMACOS_FAKE_MEDIA_INPUT="$media_input"
export OMACOS_FAKE_TRANSCODE_LOG="$temporary_directory/transcode.log"
OMACOS_MAGICK="$fake_bin/magick" OMACOS_FFMPEG="$fake_bin/ffmpeg" \
  "$project_root/scripts/transcode.zsh" choose >/dev/null
[[ -f $temporary_directory/demo-omacos.webp ]]
rg -Fq "$media_input $temporary_directory/demo-omacos.webp" "$temporary_directory/transcode.log"

share_input="$temporary_directory/share-me.txt"
print "share" > "$share_input"
export OMACOS_FAKE_SHARE_INPUT="$share_input"
OMACOS_PBPASTE="$fake_bin/pbpaste" OMACOS_AIRDROP_APP="$temporary_directory/AirDrop.app" \
  "$project_root/scripts/share.zsh" clipboard >/dev/null
rg -Fq -- "-a $temporary_directory/AirDrop.app $OMACOS_TEST_HOME/.local/state/omacos/share/Clipboard.txt" "$temporary_directory/open.log"

export OMACOS_BREW="$fake_bin/brew"
export OMACOS_FAKE_BREW_LOG="$temporary_directory/brew.log"
"$project_root/scripts/fonts.zsh" install cascadia
rg -Fq 'install --cask font-cascadia-code-nf' "$temporary_directory/brew.log"

jq -e '(.menuEntries | length) == 328 and ([.menuEntries[] | (.label | length > 0)] | all)' "$project_root/docs/quattro-inventory.json" >/dev/null

print "Complete menu, sharing, transcoding, and font adapter tests passed"
