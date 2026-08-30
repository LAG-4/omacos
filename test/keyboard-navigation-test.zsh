#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-keyboard-navigation-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

swiftc \
  "$project_root/Sources/OMacOSShell/OMacOSKeyboardSelection.swift" \
  "$test_directory/fixtures/keyboard-selection/main.swift" \
  -o "$temporary_directory/keyboard-navigation-test"

"$temporary_directory/keyboard-navigation-test"

rg -Fq '.onMoveCommand(perform: handleMoveCommand)' "$project_root/Sources/OMacOSShell/OMacOSCommandMenuView.swift"
rg -Fq '.onExitCommand(perform: handleEscapeCommand)' "$project_root/Sources/OMacOSShell/OMacOSCommandMenuView.swift"
rg -Fq '.keyboardShortcut(.cancelAction)' "$project_root/Sources/OMacOSShell/OMacOSSystemPanelView.swift"
rg -Fq 'focusInitialPanelControl' "$project_root/Sources/OMacOSShell/OMacOSShellApplication.swift"
rg -Fq 'panel.makeFirstResponder(textField)' "$project_root/Sources/OMacOSShell/OMacOSShellApplication.swift"
