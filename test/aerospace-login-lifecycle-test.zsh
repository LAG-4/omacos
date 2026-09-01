#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-aerospace-login-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

fake_home="$temporary_directory/home"
fake_state="$temporary_directory/fake-aerospace"
fake_open="$temporary_directory/open-aerospace"
fake_quit="$temporary_directory/quit-aerospace"
mkdir -p "$fake_home/.config/aerospace" "$fake_state"

cat > "$fake_open" <<'EOF'
#!/bin/zsh
set -euo pipefail
config="$OMACOS_TEST_HOME/.config/aerospace/aerospace.toml"
[[ -f $config ]] || config="$OMACOS_TEST_HOME/.aerospace.toml"
if /usr/bin/grep -Eq '^start-at-login[[:space:]]*=[[:space:]]*true' "$config"; then
  print enabled > "$OMACOS_AEROSPACE_LOGIN_STATE_FILE"
else
  print disabled > "$OMACOS_AEROSPACE_LOGIN_STATE_FILE"
fi
print running > "$OMACOS_AEROSPACE_PROCESS_STATE_FILE"
EOF

cat > "$fake_quit" <<'EOF'
#!/bin/zsh
set -euo pipefail
print stopped > "$OMACOS_AEROSPACE_PROCESS_STATE_FILE"
EOF
chmod +x "$fake_open" "$fake_quit"

run_lifecycle_case() {
  local case_name=$1
  local original_login_state=$2
  local original_process_state=$3
  local original_start_at_login=$4
  local case_home="$fake_home/$case_name"
  local login_state_file="$fake_state/$case_name-login"
  local process_state_file="$fake_state/$case_name-process"

  mkdir -p "$case_home/.config/aerospace"
  cat > "$case_home/.aerospace.toml" <<EOF
config-version = 2
start-at-login = $original_start_at_login
EOF
  original_hash=$(/usr/bin/shasum -a 256 "$case_home/.aerospace.toml" | /usr/bin/awk '{print $1}')
  print "$original_login_state" > "$login_state_file"
  print "$original_process_state" > "$process_state_file"

  OMACOS_TEST_HOME="$case_home" \
    OMACOS_ROOT="$project_root" \
    OMACOS_AEROSPACE_LOGIN_STATE_FILE="$login_state_file" \
    OMACOS_AEROSPACE_PROCESS_STATE_FILE="$process_state_file" \
    OMACOS_AEROSPACE_OPEN_COMMAND="$fake_open" \
    OMACOS_AEROSPACE_QUIT_COMMAND="$fake_quit" \
    "$project_root/scripts/aerospace-lifecycle.zsh" capture-before

  mv "$case_home/.aerospace.toml" "$case_home/original-aerospace.toml"
  cp "$project_root/config/aerospace/aerospace.toml" "$case_home/.config/aerospace/aerospace.toml"
  cp "$case_home/original-aerospace.toml" "$case_home/.aerospace.toml"
  rm "$case_home/.config/aerospace/aerospace.toml"

  OMACOS_TEST_HOME="$case_home" \
    OMACOS_ROOT="$project_root" \
    OMACOS_AEROSPACE_LOGIN_STATE_FILE="$login_state_file" \
    OMACOS_AEROSPACE_PROCESS_STATE_FILE="$process_state_file" \
    OMACOS_AEROSPACE_OPEN_COMMAND="$fake_open" \
    OMACOS_AEROSPACE_QUIT_COMMAND="$fake_quit" \
    "$project_root/scripts/aerospace-lifecycle.zsh" restore-before

  restored_hash=$(/usr/bin/shasum -a 256 "$case_home/.aerospace.toml" | /usr/bin/awk '{print $1}')
  [[ $restored_hash == $original_hash ]]
  [[ $(<"$login_state_file") == $original_login_state ]]
  if [[ $original_process_state == running ]]; then
    [[ $(<"$process_state_file") == running ]]
  else
    [[ $(<"$process_state_file") == stopped ]]
  fi
}

run_lifecycle_case disabled-before disabled stopped false
run_lifecycle_case enabled-and-running enabled running true

print 'AeroSpace login-item and process lifecycle tests passed'
