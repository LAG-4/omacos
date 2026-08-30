#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-bar-geometry-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

swiftc \
  "$project_root/Sources/OMacOSShell/OMacOSBarConfiguration.swift" \
  "$project_root/Sources/OMacOSShell/OMacOSBarGeometry.swift" \
  "$test_directory/fixtures/bar-geometry/main.swift" \
  -o "$temporary_directory/bar-geometry-test"

"$temporary_directory/bar-geometry-test"
