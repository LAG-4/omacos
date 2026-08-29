#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-window-manager-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
command_log="$temporary_home/window-manager.log"
fake_bin="$temporary_home/bin"
mkdir -p "$fake_bin" "$temporary_home/.config/omacos" "$temporary_home/.config/rift" "$temporary_home/.config/yabai"
print '{"position":"bottom","transparent":false}' > "$temporary_home/.config/omacos/bar.json"

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

cat > "$fake_bin/omacos-shell" <<'EOF'
#!/bin/zsh
print -r -- "omacos-shell $*" >> "$OMACOS_WM_TEST_LOG"
EOF

chmod +x "$fake_bin/aerospace" "$fake_bin/rift" "$fake_bin/rift-cli" "$fake_bin/yabai" "$fake_bin/omacos-shell"

export OMACOS_ROOT="$project_root"
export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_TEST_MODE=true
export OMACOS_AEROSPACE="$fake_bin/aerospace"
export OMACOS_RIFT="$fake_bin/rift"
export OMACOS_RIFT_CLI="$fake_bin/rift-cli"
export OMACOS_YABAI="$fake_bin/yabai"
export OMACOS_SHELL_BINARY="$fake_bin/omacos-shell"
export OMACOS_WM_TEST_LOG="$command_log"

wm="$project_root/scripts/window-manager.zsh"
"$wm" init
[[ $("$wm" profile) == "aerospace" ]]
rg -q '^gaps.outer.top = 8$' "$temporary_home/.config/aerospace/aerospace.toml"
rg -q '^gaps.outer.bottom = 42$' "$temporary_home/.config/aerospace/aerospace.toml"
[[ $("$wm" workspace-current) == "4" ]]
"$wm" focus left
"$wm" workspace-move 7
"$wm" workspace-move-silent 8
"$wm" workspace-next
"$wm" workspace-previous
"$wm" workspace-move-monitor left
"$wm" monitor-focus right
"$wm" focus-cycle next
"$wm" close-all
"$wm" window-width-save
"$wm" window-width-restore
rg -Fq 'aerospace focus left' "$command_log"
rg -Fq 'aerospace move-node-to-workspace --focus-follows-window 7' "$command_log"
rg -Fq 'aerospace move-node-to-workspace 8' "$command_log"
rg -Fq 'aerospace workspace --wrap-around next' "$command_log"
rg -Fq 'aerospace workspace --wrap-around prev' "$command_log"
rg -Fq 'aerospace move-workspace-to-monitor --wrap-around left' "$command_log"
rg -Fq 'aerospace focus-monitor --wrap-around right' "$command_log"
rg -Fq 'aerospace focus --wrap-around dfs-next' "$command_log"
rg -Fq 'omacos-shell --close-all-windows' "$command_log"
rg -Fq 'omacos-shell --window-width save' "$command_log"
rg -Fq 'omacos-shell --window-width restore' "$command_log"

"$wm" profile rift >/dev/null
[[ $("$wm" profile) == "rift" ]]
rg -q '^top = 8.0$' "$temporary_home/.config/rift/config.toml"
rg -q '^bottom = 42.0$' "$temporary_home/.config/rift/config.toml"
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
rg -q '^yabai -m config top_padding 8$' "$temporary_home/.config/yabai/yabairc"
rg -q '^yabai -m config bottom_padding 42$' "$temporary_home/.config/yabai/yabairc"
[[ $("$wm" workspace-current) == "5" ]]
"$wm" focus left
"$wm" move down
"$wm" toggle-workspace-layout
"$wm" scratchpad-move
rg -Fq 'yabai -m window --focus west' "$command_log"
rg -Fq 'yabai -m window --warp south' "$command_log"
rg -Fq 'yabai -m space --layout stack' "$command_log"
rg -Fq 'yabai -m window --scratchpad omacos-scratchpad' "$command_log"

"$wm" bar-position top
rg -q '^gaps.outer.top = 42$' "$temporary_home/.config/aerospace/aerospace.toml"
rg -q '^top = 42.0$' "$temporary_home/.config/rift/config.toml"
rg -q '^yabai -m config top_padding 42$' "$temporary_home/.config/yabai/yabairc"
rg -Fq 'yabai -m config bottom_padding 8' "$command_log"

"$wm" gaps disable
[[ $("$wm" gaps status) == 'window-gaps=false' ]]
rg -q '^gaps.inner.horizontal = 0$' "$temporary_home/.config/aerospace/aerospace.toml"
rg -q '^gaps.outer.top = 34$' "$temporary_home/.config/aerospace/aerospace.toml"
rg -q '^horizontal = 0.0$' "$temporary_home/.config/rift/config.toml"
rg -q '^top = 34.0$' "$temporary_home/.config/rift/config.toml"
rg -q '^yabai -m config window_gap 0$' "$temporary_home/.config/yabai/yabairc"
rg -Fq 'yabai -m config window_gap 0' "$command_log"
"$wm" gaps toggle
[[ $("$wm" gaps status) == 'window-gaps=true' ]]

"$wm" restore
[[ $(<"$temporary_home/.config/rift/config.toml") == "original rift config" ]]
[[ $(<"$temporary_home/.config/yabai/yabairc") == "original yabai config" ]]

print "Window manager adapter test passed"
