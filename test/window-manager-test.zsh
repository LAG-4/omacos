#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-window-manager-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
command_log="$temporary_home/window-manager.log"
fake_bin="$temporary_home/bin"
mkdir -p "$fake_bin" "$temporary_home/.config/rift" "$temporary_home/.config/yabai"

print "original rift config" > "$temporary_home/.config/rift/config.toml"
print "original yabai config" > "$temporary_home/.config/yabai/yabairc"

cat > "$fake_bin/aerospace" <<'EOF'
#!/bin/zsh
print -r -- "aerospace $*" >> "$OMACOS_WM_TEST_LOG"
if [[ $1 == "list-workspaces" ]]; then
  print "4"
fi
EOF

cat > "$fake_bin/rift" <<'EOF'
#!/bin/zsh
print -r -- "rift $*" >> "$OMACOS_WM_TEST_LOG"
EOF

cat > "$fake_bin/rift-cli" <<'EOF'
#!/bin/zsh
print -r -- "rift-cli $*" >> "$OMACOS_WM_TEST_LOG"
if [[ $1 == "query" && $2 == "workspaces" ]]; then
  print '[{"index":3,"is_active":true,"layout_mode":"traditional"}]'
elif [[ $1 == "query" && $2 == "workspace-layout" ]]; then
  print '[{"index":3,"is_active":true,"layout_mode":"traditional"}]'
fi
EOF

cat > "$fake_bin/yabai" <<'EOF'
#!/bin/zsh
print -r -- "yabai $*" >> "$OMACOS_WM_TEST_LOG"
if [[ $* == *"query --spaces --space"* ]]; then
  print '{"index":5,"type":"bsp"}'
fi
EOF

chmod +x "$fake_bin/aerospace" "$fake_bin/rift" "$fake_bin/rift-cli" "$fake_bin/yabai"

export OMACOS_ROOT="$project_root"
export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_TEST_MODE=true
export OMACOS_AEROSPACE="$fake_bin/aerospace"
export OMACOS_RIFT="$fake_bin/rift"
export OMACOS_RIFT_CLI="$fake_bin/rift-cli"
export OMACOS_YABAI="$fake_bin/yabai"
export OMACOS_WM_TEST_LOG="$command_log"

wm="$project_root/scripts/window-manager.zsh"
"$wm" init
[[ $("$wm" profile) == "aerospace" ]]
[[ $("$wm" workspace-current) == "4" ]]
"$wm" focus left
"$wm" workspace-move 7
rg -Fq 'aerospace focus left' "$command_log"
rg -Fq 'aerospace move-node-to-workspace 7' "$command_log"

"$wm" profile rift >/dev/null
[[ $("$wm" profile) == "rift" ]]
[[ $("$wm" workspace-current) == "3" ]]
"$wm" toggle-floating
"$wm" toggle-workspace-layout
"$wm" scratchpad-toggle
"$wm" workspace-next-monitor
"$wm" resize-grow
"$wm" join right
rg -Fq 'rift service start' "$command_log"
rg -Fq 'rift-cli execute window toggle-float' "$command_log"
rg -Fq 'rift-cli execute workspace set-layout stack' "$command_log"
rg -Fq 'rift-cli execute workspace switch 11' "$command_log"
rg -Fq 'rift-cli execute display move-window --direction right' "$command_log"
rg -Fq 'rift-cli execute window resize-grow --orientation smart' "$command_log"
rg -Fq 'rift-cli execute layout join-window right' "$command_log"

"$wm" profile yabai >/dev/null
[[ $("$wm" profile) == "yabai" ]]
[[ $("$wm" workspace-current) == "5" ]]
"$wm" focus left
"$wm" move down
"$wm" toggle-workspace-layout
"$wm" scratchpad-move
rg -Fq 'yabai -m window --focus west' "$command_log"
rg -Fq 'yabai -m window --warp south' "$command_log"
rg -Fq 'yabai -m space --layout stack' "$command_log"
rg -Fq 'yabai -m window --scratchpad omacos-scratchpad' "$command_log"

"$wm" restore
[[ $(<"$temporary_home/.config/rift/config.toml") == "original rift config" ]]
[[ $(<"$temporary_home/.config/yabai/yabairc") == "original yabai config" ]]

print "Window manager adapter test passed"
