#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-pointer-gesture-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_shell="$temporary_home/omacos-shell"
command_log="$temporary_home/pointer.log"

cat > "$fake_shell" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_POINTER_TEST_LOG"
EOF
chmod +x "$fake_shell"

export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_SHELL_BINARY="$fake_shell"
export OMACOS_POINTER_TEST_LOG="$command_log"

for action in super-down begin-move end begin-resize super-up; do
  "$project_root/bin/omacos" pointer "$action"
done

rg -Fxq -- '--pointer-gesture super-down' "$command_log"
rg -Fxq -- '--pointer-gesture begin-move' "$command_log"
rg -Fxq -- '--pointer-gesture begin-resize' "$command_log"
rg -Fxq -- '--pointer-gesture end' "$command_log"
rg -Fxq -- '--pointer-gesture super-up' "$command_log"

print "Native Super pointer gesture routing test passed"
