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

Current progress: the shared panel command API, clickable bar affordances, keybinding reference, complete 328-entry searchable Quattro menu hierarchy, system menu, calendar, audio, Bluetooth, network, display, power, activity, clipboard, emoji, reminders, notification history, screenshots, system-audio recording, QR and text recognition, local transcoding, AirDrop handoff, themes, backgrounds, fonts, application defaults, web apps, agent usage, weather, media, notices, shell toggles, native dictation, OSD, developer gallery, Wi-Fi QR, speed tests, Tailscale, Dropbox, optional apps, and the 29-plugin parity catalog are implemented. All 22 semantic palettes are imported without bundling unverified wallpapers. The default install includes the portable shell toolchain, reversible zsh integration, tmux layouts, and an isolated Neovim profile. Managed snapshots, migrations, update, and rollback are tested. Window and workspace actions now cross a tested adapter boundary with AeroSpace as the default, Rift as an experimental SIP-on profile, and yabai as an optional SIP-on profile. The generated 879-item parity ledger has no portable-pending entries. Permission diagnostics, privacy-safe hardware reports, and the signed/notarized tag workflow are implemented. Physical one-, two-, and three-display runs, sleep/lid/notch validation, supplying production Apple credentials, and the deliberately manual yabai scripting-addition path remain release work.

## Milestone 2: Quattro shell parity

- Add audio, Wi-Fi, Bluetooth, display, power, calendar, weather, media, activity, and agent panels.
- Add local dictation and agent usage collectors.
- Port all licensed semantic themes and generate configuration for supported developer tools.
- Define the out-of-process plugin provider contract.

## Milestone 3: alternate window managers and release engineering

- Validate the experimental Rift profile across multiple displays and native Spaces on supported hardware.
- Validate the isolated yabai profile with SIP enabled, then document the separately tested manual scripting-addition path.
- Sign and notarize the native application.
- Publish pinned releases, migrations, rollback, hardware test results, and update channels.
