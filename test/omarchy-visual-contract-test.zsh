#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
contract="$project_root/Sources/OMacOSShell/Resources/omarchy-shell-contract.json"

[[ -f $contract ]]

jq -e '
  .schemaVersion == 1 and
  .reference.repository == "basecamp/omarchy" and
  .reference.commit == "0b3f1b7ead00ac4bcbaae8bac16bab3f7efbe516" and
  .bar.horizontalSize == 26 and
  .bar.verticalSize == 28 and
  .bar.centerAnchor == "omarchy.clock" and
  (.bar.layout.left == ["omarchy.menu", "omarchy.workspaces"]) and
  (.bar.layout.center == ["omarchy.indicators", "omarchy.clock", "omarchy.keyboard-layout", "omarchy.weather", "omarchy.system-update"]) and
  (.bar.layout.right == ["omarchy.tray", "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor", "omarchy.power"]) and
  .menu.width == 300 and
  .menu.specialWidth == 520 and
  .menu.panelPadding == 18 and
  .menu.headerHeight == 34 and
  .menu.rowHeight == 50 and
  .menu.detailRowHeight == 58 and
  .menu.rowSpacing == 3 and
  .menu.contentSpacing == 6 and
  .menu.cornerRadius == 0 and
  .menu.maximumScreenHeightFraction == 0.7 and
  .typography.family == "JetBrainsMono Nerd Font" and
  .typography.base == 12 and
  .typography.heading == 16 and
  .spacing.windowInner == 5 and
  .spacing.windowOuter == 10 and
  .animation.themeColorMilliseconds == 420 and
  .animation.interactionMilliseconds == 140
' "$contract" >/dev/null

rg -Fq 'static let shared = OMacOSShellContract.loadBundled()' "$project_root/Sources/OMacOSShell/OMacOSShellContract.swift"
rg -Fq 'OMacOSShellContract.shared.bar.horizontalSize' "$project_root/Sources/OMacOSShell/OMacOSBarGeometry.swift"
rg -Fq 'OMacOSShellContract.shared.typography.family' "$project_root/Sources/OMacOSShell/OMacOSBarView.swift"
rg -Fq 'CGFloat(contract.menu.width)' "$project_root/Sources/OMacOSShell/OMacOSCommandMenuView.swift"

if rg -Fq 'frontmostApplication' "$project_root/Sources/OMacOSShell/OMacOSBarView.swift"; then
  print -u2 "The default Quattro bar does not contain an active-window widget"
  exit 1
fi

print "Frozen Omarchy visual contract test passed"
