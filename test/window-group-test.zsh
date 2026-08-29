#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-window-group-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_shell="$temporary_home/omacos-shell"
command_log="$temporary_home/group.log"

cat > "$fake_shell" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_GROUP_TEST_LOG"
EOF
chmod +x "$fake_shell"

export OMACOS_TEST_HOME="$temporary_home"
export OMACOS_SHELL_BINARY="$fake_shell"
export OMACOS_GROUP_TEST_LOG="$command_log"

"$project_root/bin/omacos" group toggle
"$project_root/bin/omacos" group join left
"$project_root/bin/omacos" group out
"$project_root/bin/omacos" group next
"$project_root/bin/omacos" group previous
"$project_root/bin/omacos" group index 5

rg -Fxq -- '--window-group toggle' "$command_log"
rg -Fxq -- '--window-group join left' "$command_log"
rg -Fxq -- '--window-group out' "$command_log"
rg -Fxq -- '--window-group next' "$command_log"
rg -Fxq -- '--window-group previous' "$command_log"
rg -Fxq -- '--window-group index 5' "$command_log"

print "Native window group routing test passed"
