# Hardware validation

Run this checklist on clean Apple Silicon test users. Save `omacos qa report REPORT.json` with the results; the report deliberately omits serial numbers, hardware UUIDs, hostnames, account names, network names, and application data.

## Required matrix

| Variable | Required coverage |
| --- | --- |
| macOS | Tahoe 26 current patch; macOS 27 current beta or release |
| SoC | At least one base Apple Silicon chip and one Pro/Max-class chip |
| Displays | Built-in only; one external; two external; clamshell where the hardware supports it |
| Display shape | Notched built-in panel; non-notched external panel; mixed scale factors |
| Window manager | AeroSpace required; Rift experimental; yabai SIP-on optional |
| Permissions | Fresh approval; revoked; reapproved; shell identity retained across update |

## Installation and reversal

1. Start from a user with an existing AeroSpace config and a non-empty `.zshrc`.
2. Run the public curl installer, decline it once, then run it again and accept.
3. Confirm the original files were backed up and the installer never asks to weaken SIP.
4. Enable the named Karabiner complex modification and approve only the permissions needed by the tested workflows.
5. Run `omacos doctor`, `omacos permissions status`, and `omacos qa report before.json`.
6. Run `omacos uninstall`, then verify the original AeroSpace config and `.zshrc` bytes are restored.
7. Confirm OMacOS LaunchAgents and processes are absent. Homebrew packages should remain, as stated in the uninstall plan.

## Shell and display behavior

1. Confirm one bar appears on every connected display and avoids the notch safe area.
2. Open every panel from the bar and from its Right Option shortcut.
3. Enter and leave native fullscreen on each display; the bar and overlays must neither strand nor steal focus.
4. Attach and detach displays in every tested arrangement. No duplicate or off-screen bar may remain.
5. Sleep and wake the Mac three times, including one lid close/open cycle on a notebook.
6. Change display scaling and rotation where supported, then repeat panel placement checks.
7. Verify the OSD closes itself and the command menu opens directly into requested submenus.

## Window and input behavior

1. Confirm Command and Left Option retain normal macOS editing behavior.
2. Confirm tapping Right Option alone still emits Right Option.
3. Exercise focus, swap, join, resize, float, fullscreen, layout, scratchpad, next/previous/former workspace, all ten numbered workspaces, and directional monitor movement.
4. Verify Super+C/V/X produces native Command copy/paste/cut in text fields and terminals.
5. Save and restore a focused window width; revoke Accessibility and confirm the command fails with a useful explanation.
6. Trigger close-all only with disposable windows and confirm it leaves no managed application window behind.

## Capture, voice, and services

1. Capture a region, full screen, text, QR code, and color. Record without audio, with microphone, with system audio, and with both.
2. Revoke Screen Recording and confirm the next capture explains how to recover.
3. Test F9 push-to-talk and the toggle shortcut with on-device recognition available and unavailable.
4. Verify clipboard concealment, reminders after sleep/wake, Apple Music and Spotify controls, Wi-Fi QR, Tailscale, Dropbox, network speed, and disk speed.
5. Apply every bundled theme and inspect the bar, menu, panels, OSD, Ghostty, borders, tmux, Neovim, and generated editor/TUI files.

## Release acceptance

1. Install a Developer ID-signed, notarized archive on a Mac that has never built OMacOS.
2. Verify `codesign --verify --deep --strict OMacOSShell.app`, `spctl --assess --type execute --verbose OMacOSShell.app`, and `xcrun stapler validate OMacOSShell.app`.
3. Update to the next signed build and confirm macOS retains permission grants for the stable `dev.omacos.shell` identity.
4. Roll back the update and verify configuration, version, shell startup, and all user data.

Do not mark a hardware row complete from CI, a virtual machine, or a single-display desktop capture. Record failures and exact hardware conditions instead of converting them into assumed support.
