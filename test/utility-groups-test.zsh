#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-utilities-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_bin="$temporary_home/bin"
mkdir -p "$fake_bin" "$temporary_home/.config/omacos/hooks"
command_log="$temporary_home/commands.log"

cat > "$fake_bin/osascript" <<'EOF'
#!/bin/zsh
print '/tmp/chosen item'
EOF

cat > "$fake_bin/mise" <<'EOF'
#!/bin/zsh
print -r -- "mise $*" >> "$OMACOS_UTILITY_TEST_LOG"
EOF

cat > "$temporary_home/.config/omacos/hooks/hello" <<'EOF'
#!/bin/zsh
print -r -- "hook $*" >> "$OMACOS_UTILITY_TEST_LOG"
EOF

chmod +x "$fake_bin/osascript" "$fake_bin/mise" "$temporary_home/.config/omacos/hooks/hello"
export OMACOS_ROOT="$project_root"
export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_TEST_MODE=true
export OMACOS_OSASCRIPT="$fake_bin/osascript"
export OMACOS_MISE="$fake_bin/mise"
export OMACOS_UTILITY_TEST_LOG="$command_log"

utilities="$project_root/scripts/utilities.zsh"
[[ $("$utilities" file choose) == '/tmp/chosen item' ]]
[[ $("$utilities" channel status) == 'stable' ]]
[[ $("$utilities" channel list) == *'Signed and notarized GitHub releases'* ]]
[[ $("$utilities" channel list) == *'GitHub prereleases'* ]]
"$utilities" channel set edge >/dev/null
[[ $("$utilities" channel status) == 'edge' ]]
"$utilities" channel set rc >/dev/null
[[ $("$utilities" channel status) == 'rc' ]]
"$utilities" channel set dev >/dev/null
[[ $("$utilities" channel status) == 'dev' ]]
"$utilities" channel set stable >/dev/null
[[ $("$utilities" version) == OMacOS* ]]
"$utilities" hook run hello one two
"$utilities" mise install node@lts
rg -Fq 'hook one two' "$command_log"
rg -Fq 'mise install node@lts' "$command_log"
"$utilities" ascii OM >/dev/null

print 'Portable Quattro utility group tests passed'
