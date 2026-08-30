# Implementation roadmap

## Milestone 0: interaction proof

- Install and remove the environment without losing existing configuration.
- Use Right Option as Super without changing Command or Left Option.
- Reproduce the main Omarchy tiling, workspace, launch, and command-menu shortcuts through AeroSpace.
- Keep a native bar stable across display changes, fullscreen, sleep, and wake.
- Apply one semantic theme across the native shell, Ghostty, and borders.

## Milestone 1: useful daily environment

- Add application defaults, terminal tooling, tmux, Neovim, browsers, and web-app launchers.
- Add launcher, keybinding help, system menu, theme picker, wallpaper picker, and updater UI.
- Add clipboard history, emoji picker, reminders, screenshots, recordings, and OCR.
- Test one-display, multi-display, clamshell, notch, fullscreen, and permission-revocation cases.

Current progress: the shared panel command API, clickable four-edge bar with horizontal and vertical layouts, runtime transparency, keybinding reference, and a 114-entry macOS command menu projected from the complete frozen 328-entry Quattro reference are implemented. The projection keeps Linux-only concepts in the parity ledger without exposing them as macOS actions. The system menu, calendar, audio, Bluetooth, network, display, power, activity, clipboard, emoji, reminders, actionable OMacOS notification history, screenshots, system-audio and native-webcam-overlay recording, QR and text recognition, local transcoding, AirDrop handoff, themes, backgrounds, fonts, application defaults, web apps, agent usage, weather, media, notices, shell toggles, native dictation, OSD, developer gallery, Wi-Fi QR, speed tests, Tailscale, Dropbox, optional apps, and the 29-plugin parity catalog are implemented. All 22 semantic palettes are imported without bundling unverified wallpapers. The default install includes the portable shell toolchain, reversible zsh integration, tmux layouts, and an isolated Neovim profile. Managed snapshots, migrations, stable/RC/edge/dev update channels, and rollback are tested. Window and workspace actions cross a tested adapter boundary with AeroSpace as the default, Rift as an experimental SIP-on profile, and yabai as an optional SIP-on profile. Native Accessibility layers provide pointer gestures, retained pseudotiling, and compositor-independent overlapping window groups where WindowServer lacks a portable tiler feature. The generated 879-item parity ledger contains 637 implemented outcomes, 157 explicit limited substitutions, 85 not-applicable Linux/platform outcomes, and zero pending or unavailable entries. Implemented CLI groups and all projected menu actions have executable-route audits. Permission diagnostics, privacy-safe hardware reports, and the signed/notarized tag workflow are implemented. Physical one-, two-, and three-display runs, camera/microphone capture approval, sleep/lid/notch/fullscreen validation, supplying production Apple credentials, and the deliberately manual yabai scripting-addition path remain release work.

## Milestone 2: Quattro shell parity

- Add audio, Wi-Fi, Bluetooth, display, power, calendar, weather, media, activity, and agent panels.
- Add local dictation and agent usage collectors.
- Port all licensed semantic themes and generate configuration for supported developer tools.
- Define the out-of-process plugin provider contract.

## Milestone 3: alternate window managers and release engineering

- Validate the experimental Rift profile across multiple displays and native Spaces on supported hardware.
- Validate the isolated yabai profile with SIP enabled, then document the separately tested manual scripting-addition path.
- Sign and notarize the native application.
- Publish the first production-signed tag and physical hardware test results. Stable, RC, edge, and dev channels, migrations, and rollback are implemented.
