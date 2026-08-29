#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
shell_binary="$project_root/.build/debug/omacos-shell"
temporary_home=$(mktemp -d -t omacos-notification-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-add Build 'The build completed.' >/dev/null
notification_output=$(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list)
[[ $notification_output == *$'Build\tThe build completed.'* ]]

mkdir -p "$temporary_home/.local/state/omacos/toggles"
touch "$temporary_home/.local/state/omacos/toggles/notification-silencing.enabled"
OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --reminder-add 0 'silent reminder' >/dev/null
OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --reminder-deliver
notification_output=$(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list)
[[ $notification_output == *$'OMacOS Reminder\tsilent reminder'* ]]

OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-clear
[[ -z $(OMACOS_TEST_HOME="$temporary_home" "$shell_binary" --notification-list) ]]

print 'OMacOS notification history tests passed'
