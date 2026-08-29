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

## Milestone 2: Quattro shell parity

- Add audio, Wi-Fi, Bluetooth, display, power, calendar, weather, media, activity, and agent panels.
- Add local dictation and agent usage collectors.
- Port all licensed semantic themes and generate configuration for supported developer tools.
- Define the out-of-process plugin provider contract.

## Milestone 3: alternate window managers and release engineering

- Add Rift as an experimental SIP-on profile.
- Add an isolated yabai power profile with explicit security warnings.
- Sign and notarize the native application.
- Publish pinned releases, migrations, rollback, hardware test results, and update channels.

