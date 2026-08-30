#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-workspace-monitor-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

swiftc \
  "$project_root/Sources/OMacOSShell/OMacOSWorkspaceMonitor.swift" \
  "$test_directory/fixtures/workspace-monitor/main.swift" \
  -o "$temporary_directory/workspace-monitor-test"

"$temporary_directory/workspace-monitor-test"
