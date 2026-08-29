#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-zoom-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
command_log="$temporary_home/commands.log"

fake_shell="$temporary_home/omacos-shell"
fake_open="$temporary_home/open"

cat > "$fake_shell" <<'EOF'
#!/bin/zsh
print -r -- "shell $*" >> "$OMACOS_ZOOM_TEST_LOG"
EOF

cat > "$fake_open" <<'EOF'
#!/bin/zsh
print -r -- "open $*" >> "$OMACOS_ZOOM_TEST_LOG"
EOF

chmod +x "$fake_shell" "$fake_open"

export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_SHELL_BINARY="$fake_shell"
export OMACOS_OPEN_BINARY="$fake_open"
export OMACOS_ZOOM_TEST_LOG="$command_log"

"$project_root/bin/omacos" zoom in
"$project_root/bin/omacos" zoom reset
"$project_root/bin/omacos" zoom setup

rg -Fq 'shell --system-zoom in' "$command_log"
rg -Fq 'shell --system-zoom reset' "$command_log"
rg -Fq 'open x-apple.systempreferences:com.apple.Accessibility-Settings.extension' "$command_log"

print "Native accessibility zoom routing test passed"
