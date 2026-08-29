#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-focused-directory-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_bin="$temporary_home/bin"
expected_directory="$temporary_home/project with spaces"
open_log="$temporary_home/open.log"
mkdir -p "$fake_bin" "$expected_directory"

cat > "$fake_bin/pgrep" <<'EOF'
#!/bin/zsh
if [[ $2 == "100" ]]; then
  print 200
elif [[ $2 == "200" ]]; then
  print 300
fi
EOF

cat > "$fake_bin/lsof" <<'EOF'
#!/bin/zsh
process_id=${@[-1]}
print "p$process_id"
print "fcwd"
if [[ $process_id == "200" ]]; then
  print "n$OMACOS_FOCUSED_DIRECTORY_PARENT"
elif [[ $process_id == "300" ]]; then
  print "n$OMACOS_FOCUSED_DIRECTORY_EXPECTED"
fi
EOF

chmod +x "$fake_bin/pgrep" "$fake_bin/lsof"

resolved_directory=$(
  OMACOS_FRONTMOST_PID=100 \
  OMACOS_FRONTMOST_PROCESS_NAME=Ghostty \
  OMACOS_PGREP_BINARY="$fake_bin/pgrep" \
  OMACOS_LSOF_BINARY="$fake_bin/lsof" \
  OMACOS_FOCUSED_DIRECTORY_PARENT="$temporary_home" \
  OMACOS_FOCUSED_DIRECTORY_EXPECTED="$expected_directory" \
  "$project_root/scripts/focused-directory.zsh"
)
[[ $resolved_directory == "$expected_directory" ]]

OMACOS_FAKE_OPEN_LOG="$open_log" \
OMACOS_OPEN_BINARY="$test_directory/fixtures/fake-open.zsh" \
OMACOS_FRONTMOST_PID=100 \
OMACOS_FRONTMOST_PROCESS_NAME=Ghostty \
OMACOS_PGREP_BINARY="$fake_bin/pgrep" \
OMACOS_LSOF_BINARY="$fake_bin/lsof" \
OMACOS_FOCUSED_DIRECTORY_PARENT="$temporary_home" \
OMACOS_FOCUSED_DIRECTORY_EXPECTED="$expected_directory" \
"$project_root/scripts/launch.zsh" files-cwd
rg -Fxq -- "$expected_directory" "$open_log"

if OMACOS_FRONTMOST_PID=100 OMACOS_FRONTMOST_PROCESS_NAME=Finder \
  "$project_root/scripts/focused-directory.zsh" >/dev/null 2>&1; then
  print -u2 "Focused-directory adapter accepted a non-terminal application"
  exit 1
fi

print "Focused terminal directory adapter test passed"
