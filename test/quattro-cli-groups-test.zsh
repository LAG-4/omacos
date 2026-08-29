#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_home=$(mktemp -d -t omacos-quattro-groups-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_bin="$temporary_home/bin"
command_log="$temporary_home/commands.log"
mkdir -p "$fake_bin" "$temporary_home/.local/state/omacos"

cat > "$fake_bin/omacos-shell" <<'EOF'
#!/bin/zsh
print -r -- "shell $*" >> "$OMACOS_QUATTRO_GROUP_LOG"
EOF
cat > "$fake_bin/open" <<'EOF'
#!/bin/zsh
print -r -- "open $*" >> "$OMACOS_QUATTRO_GROUP_LOG"
EOF
cat > "$fake_bin/osascript" <<'EOF'
#!/bin/zsh
print -r -- "osascript $*" >> "$OMACOS_QUATTRO_GROUP_LOG"
print 'output volume:42, input volume:50, alert volume:50, output muted:false'
EOF
cat > "$fake_bin/pmset" <<'EOF'
#!/bin/zsh
print "Now drawing from 'Battery Power' -InternalBattery-0 (id=1) 77%; discharging"
EOF
cat > "$fake_bin/blueutil" <<'EOF'
#!/bin/zsh
print -r -- "blueutil $*" >> "$OMACOS_QUATTRO_GROUP_LOG"
[[ ${1:-} == '--power' && $# == 1 ]] && print 1
EOF
cat > "$fake_bin/tailscale" <<'EOF'
#!/bin/zsh
print '{"Self":{"Online":false},"Peer":{}}'
EOF
chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH"
export OMACOS_ROOT="$project_root"
export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_TEST_MODE=true
export OMACOS_SHELL_BINARY="$fake_bin/omacos-shell"
export OMACOS_OPEN_BINARY="$fake_bin/open"
export OMACOS_OSASCRIPT="$fake_bin/osascript"
export OMACOS_PMSET="$fake_bin/pmset"
export OMACOS_BLUEUTIL="$fake_bin/blueutil"
export OMACOS_QUATTRO_GROUP_LOG="$command_log"

cli="$project_root/bin/omacos"
"$cli" audio status >/dev/null
"$cli" bar status >/dev/null
"$cli" battery status >/dev/null
"$cli" bluetooth status >/dev/null
"$cli" branding status >/dev/null
"$cli" clipboard list >/dev/null
"$cli" clipboard clear >/dev/null
[[ $(<"$temporary_home/.local/state/omacos/clipboard-history.json") == '[]' ]]
"$cli" cmd present zsh
[[ $("$cli" config path) == "$temporary_home/.config/omacos" ]]
"$cli" debug status >/dev/null
"$cli" dev status >/dev/null
"$cli" disk status >/dev/null
"$cli" games list >/dev/null
"$cli" install show
"$cli" monitor show
"$cli" power status >/dev/null
"$cli" remove show
"$cli" setup show
"$cli" snapshot list >/dev/null
"$cli" system show
"$cli" tailscale status >/dev/null
"$cli" wifi settings

rg -Fq 'shell --clipboard-clear' "$command_log"
rg -Fq 'shell --toggle-panel packages' "$command_log"
rg -Fq 'shell --toggle-panel display' "$command_log"
rg -Fq 'shell --toggle-menu setup' "$command_log"
rg -Fq 'open x-apple.systempreferences:com.apple.wifi-settings-extension' "$command_log"

print 'Quattro compatibility CLI group tests passed'
