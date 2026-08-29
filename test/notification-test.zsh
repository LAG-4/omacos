#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
shell_binary="$project_root/.build/debug/omacos-shell"
temporary_home=$(mktemp -d -t omacos-notification-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_open="$temporary_home/open"
open_log="$temporary_home/open.log"
command cat > "$fake_open" <<'EOF'
#!/bin/zsh
print -r -- "$*" > "$OMACOS_NOTIFICATION_OPEN_LOG"
EOF
chmod +x "$fake_open"

OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-add Build 'The build completed.' >/dev/null
notification_output=$(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list)
[[ $notification_output == *$'Build\tThe build completed.'* ]]

OMACOS_TEST_HOME="$temporary_home" OMACOS_SHELL_BINARY="$shell_binary" \
  "$project_root/bin/omacos" notification add Deploy 'Deployment completed.' 'https://example.com/deploy/42' >/dev/null
OMACOS_TEST_HOME="$temporary_home" OMACOS_SHELL_BINARY="$shell_binary" \
  OMACOS_OPEN_BINARY="$fake_open" OMACOS_NOTIFICATION_OPEN_LOG="$open_log" \
  "$project_root/bin/omacos" notification invoke-one
[[ $(<"$open_log") == 'https://example.com/deploy/42' ]]

mkdir -p "$temporary_home/.local/state/omacos/toggles"
touch "$temporary_home/.local/state/omacos/toggles/notification-silencing.enabled"
OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --reminder-add 0 'silent reminder' >/dev/null
OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --reminder-deliver
notification_output=$(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list)
[[ $notification_output == *$'OMacOS Reminder\tsilent reminder'* ]]

dismissed_output=$(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-dismiss-one)
[[ $dismissed_output == *$'OMacOS Reminder\tsilent reminder'* ]]
notification_output=$(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list)
[[ $notification_output != *$'OMacOS Reminder\tsilent reminder'* ]]
[[ $notification_output == *$'Build\tThe build completed.'* ]]

OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-clear
[[ -z $(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list) ]]

print 'OMacOS notification history tests passed'
