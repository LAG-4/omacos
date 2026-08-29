# OMacOS feasibility report

Research frozen on 2026-08-29.

## Verdict

A high-fidelity Omarchy experience is viable as a customization layer on an existing Mac. OMacOS can reproduce the visible shell it owns, tiling workflows, shortcut vocabulary, semantic themes, terminal environment, launchers, pickers, capture tools, OCR, local dictation, agent integrations, installation, updates, migrations, backup, and uninstall.

It cannot replace WindowServer, Apple's login or authenticated lock screens, Control Center, system permission prompts, FileVault and preboot UI, or the notification history of unrelated applications through supported public APIs. macOS also does not provide a public API for replacing or fully controlling native Spaces. “One-to-one” therefore means the same visible design, commands, naming, workflows, and outcomes where macOS permits them.

The recommended product is a distinct open-source Mac project inspired by Omarchy. It should not claim to be an official Omarchy edition.

## Frozen Omarchy reference

The reference checkout was the local `quattro` branch at commit `0b3f1b7ead00ac4bcbaae8bac16bab3f7efbe516`, dated 2026-08-29.

The inventory covered:

- 51 manual chapters
- 29 Quattro plugin and widget manifests
- 68 visible CLI groups from `bin/omarchy`
- 22 semantic themes
- 17 generated theme targets
- all default shortcut families in `default/hypr/bindings`
- installer, migration, package, backup, update, agent, shell, and theming code

Omarchy itself is MIT licensed. Any substantial copied code must retain the original copyright and MIT notice. Wallpapers, logos, fonts, icons, palettes, and third-party application assets require separate license checks.

## Input model

Using Command as Super would break standard Mac shortcuts such as Save, Open, Find, Quit, application switching, and Spotlight. Using both Option keys would preserve Command but steal word navigation, word deletion, text selection, alternate characters, and application-specific Option actions.

OMacOS uses Right Option as a dedicated physical Super layer. Karabiner-Elements consumes Right Option while held and dispatches OMacOS bindings. Pressing Right Option alone still emits Right Option. Left Option and Command remain native. This also preserves distinct `Super`, `Super+Shift`, `Super+Control`, and `Super+Option` tiers, which a conventional four-modifier Hyper mapping cannot do because Shift, Control, and Option are already held inside Hyper.

A later profile can use Caps Lock as the same layer, with tap-to-Escape behavior. A both-Option-keys profile should remain opt-in.

## Window manager decision

### Default: AeroSpace

AeroSpace is the safe default. It uses public Accessibility APIs, works with SIP enabled, has an i3-like tree, tiles and accordion layouts, virtual workspaces, a CLI, callbacks, and multi-monitor commands. Its documented installation uses `brew install --cask nikitabobko/tap/aerospace`. AeroSpace searches `~/.aerospace.toml` and then `${XDG_CONFIG_HOME}/aerospace/aerospace.toml`; having both is an error, so the installer must back up and resolve that ambiguity. See the [AeroSpace guide](https://nikitabobko.github.io/AeroSpace/guide).

AeroSpace does not implement Hyprland's compositor, dwindle layout, exact groups, animation model, opacity, pinning, or native Spaces. It emulates workspaces by moving inactive windows away from the visible desktop. This is close enough for the safe default, but the adapter boundary must prevent AeroSpace semantics from leaking into the native shell.

Use upstream AeroSpace and pin tested versions. Do not fork it before a concrete upstream limitation blocks the product.

### Experimental SIP-on profile: Rift

[Rift](https://github.com/acsandmann/rift) offers i3, BSP, master-stack, scrolling, and stack layouts, plus animations, gestures, custom Mission Control behavior, and SketchyBar events. It keeps SIP enabled but explicitly uses private and undocumented APIs reverse-engineered from yabai. It may achieve better visual and layout parity than AeroSpace, with greater macOS-update risk. Treat it as an experimental adapter and contribute fixes upstream before considering a fork.

### Optional power profile: yabai

[yabai](https://github.com/asmvik/yabai) is the closest route to native Space manipulation, opacity, shadows, sticky windows, layers, scratchpads, and deeper WindowServer control. Basic operation works with SIP enabled. Its scripting addition requires partial SIP disablement on Apple Silicon, including reduced filesystem, debugging, and NVRAM protections, as described in the [official SIP instructions](https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection).

The yabai profile must be isolated, optional, and accompanied by a plain security warning. The normal installer must never weaken SIP.

## Shell architecture

Quickshell targets Wayland and X11, and Quattro depends on Linux services. Its QML cannot become the macOS runtime. OMacOS can reuse licensed assets, pure JavaScript ideas, layout behavior, semantic tokens, and interaction design. See the [Quickshell source](https://github.com/quickshell-mirror/quickshell).

The durable shell should be a native Swift application using AppKit windows and SwiftUI content:

```text
Signed OMacOS application
├── per-display top bars
├── command menu, panels, pickers, overlays and OSD
├── semantic theme runtime
├── permission onboarding
├── local background services
│   ├── capture, OCR and dictation
│   ├── clipboard and reminders
│   ├── agent usage collectors
│   └── macOS status providers
├── Unix socket or XPC command API
└── replaceable adapters
    ├── AeroSpace, Rift or yabai
    ├── Karabiner input profiles
    ├── Homebrew packages
    └── public macOS frameworks or native handoff
```

[SketchyBar](https://felixkratz.github.io/SketchyBar/features) is useful for prototypes and compatibility. It has events, popups, animations, and menu aliases, but it does not provide a coherent runtime for Quattro's full panels, pickers, OSD, permission onboarding, and plugin lifecycle. SwiftBar, xbar, and Übersicht are better for independent widgets than for the core shell.

Native plugins should use declarative manifests and out-of-process JSON or XPC providers. Loading arbitrary unsigned code into the shell process would complicate the hardened runtime and expose every permission held by the host.

## Parity ledger

| Omarchy subsystem | macOS implementation | Grade | Permissions and limits |
| --- | --- | --- | --- |
| Tiling and directional focus | AeroSpace | Close substitute | Accessibility; no Hyprland compositor |
| Workspaces | AeroSpace virtual workspaces | Close substitute | Not native Spaces |
| Native Space power features | Optional yabai scripting addition | Unsafe optional parity | Partial SIP disablement |
| Shortcut vocabulary | Right Option Karabiner layer | Exact for bound outcomes | Input Monitoring; user approval |
| Bar, menu and panels | Swift/AppKit host | Exact for owned UI | Cannot replace Control Center |
| Window borders | JankyBorders or native recreation | Close substitute | Accessibility; GPL if distributed as a separate tool |
| Launcher and application defaults | NSWorkspace and `open` adapters | Exact or native replacement | Application availability varies |
| Notifications | OMacOS-owned notification center | Partial | Cannot read all other app notifications |
| Clipboard history | Native service or external [Maccy](https://github.com/p0deje/Maccy) | Close substitute | Accessibility may be needed for universal paste |
| Emoji picker | Native Swift picker and macOS character APIs | Exact for outcome | None for owned picker |
| Wallpapers | `NSWorkspace.setDesktopImageURL` | Exact for outcome | Public API; per-screen behavior must be tested |
| Themes | Shared JSON schema and generators | Exact for owned UI and supported tools | Arbitrary native apps cannot be recolored |
| OSD | AppKit overlay panels | Exact for project-controlled changes | System OSD cannot be replaced globally |
| Lock and idle | Native lock and power APIs | Native replacement | Login screen remains Apple-owned |
| Screenshots and recording | ScreenCaptureKit | Exact or better | Screen Recording permission |
| OCR | Vision text recognition | Exact for outcome | On-device; Screen Recording for direct capture |
| Dictation | Local Whisper service; VoiceInk as reference | Close substitute | Microphone and Accessibility for paste |
| Audio mixer | CoreAudio process taps | Close substitute | System Audio Recording permission; macOS 14.2+ |
| Displays | Public APIs plus MonitorControl handoff | Close substitute | DDC depends on display and connection hardware |
| Wi-Fi | CoreWLAN and native settings handoff | Native replacement | Public query support; protected changes may need UI |
| Bluetooth | CoreBluetooth and native settings handoff | Partial | General system-device management is limited |
| Reminders and calendar | EventKit | Exact for outcome | Explicit per-data permission |
| Weather | WeatherKit | Exact for outcome | Attribution and service entitlement |
| Media | App-owned Now Playing plus adapters | Partial | No reliable public global now-playing inspection |
| Agent usage | Portable JSON collectors plus Swift UI | Near exact | Agent schemas and credentials vary |
| Crash diagnosis | DiagnosticReports adapter | Close substitute | Replaces systemd-coredump workflow |
| Packages | Homebrew Bundle | Native replacement | Brewfile is declarative, not a true lock file |
| Updates | Signed releases plus Sparkle | Native replacement | Signing and notarization needed for production |
| Login services | `SMAppService` or LaunchAgents | Native replacement | User or administrator approval may apply |
| Backup | OMacOS state ledger plus user backups | Close substitute | Time Machine snapshots are temporary and not factory reset |
| Uninstall | Restore captured files and remove owned state | Exact for OMacOS changes | Third-party packages remain unless explicitly requested |

Relevant Apple documentation includes [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [Vision OCR](https://developer.apple.com/documentation/vision/recognizing-text-in-images), [EventKit](https://developer.apple.com/documentation/eventkit/accessing-the-event-store), [WeatherKit](https://developer.apple.com/documentation/weatherkit), [CoreAudio process taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps), [CoreWLAN](https://developer.apple.com/documentation/corewlan), [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth), [UserNotifications](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter), and [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).

macOS requires users to grant Accessibility and privacy permissions. A normal installer cannot silently approve them. Apple documents Accessibility control in [Mac Help](https://support.apple.com/en-gb/guide/mac-help/mh43185/mac). Managed-device administrators can preconfigure some privacy preferences, but that is a separate MDM deployment model.

## Themes

Port Omarchy's semantic color model into a shared versioned schema. Generate native shell colors and configurations for Ghostty, Kitty, Alacritty, btop, Helix, Neovim, VS Code, Chromium, Claude, Pi, Obsidian, borders, gaps, and wallpapers. Keep the schema separate from every renderer so changing one target does not alter the theme definition.

Exact parity is realistic for OMacOS UI and tools with supported theme formats. macOS does not allow a third party to recolor arbitrary native applications consistently.

## Agent integrations

Omarchy Quattro's agent plugin contract is portable. Collectors emit JSON for Claude, Codex, and Fireworks usage and limits, with local statistics and optional sync. OMacOS can port collectors with small path and process changes and render them in Swift. Agent launching, lazy installation, default-agent selection, and prompt workflows are also portable.

## Installation and release model

The public command can be:

```bash
curl -fsSL https://raw.githubusercontent.com/LAG-4/omacos/main/install.sh | zsh
```

The fetched bootstrap must remain short and readable. It downloads a versioned source or signed release, prints its plan, requests confirmation, and starts the installer. The installer records original files before changing them and provides dry-run, doctor, update, backup, and reversible uninstall commands.

Production releases should use a Developer ID signed and notarized `.app`, `.dmg`, or `.pkg` with Hardened Runtime. Apple documents [macOS distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) and [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). App Sandbox is optional for direct distribution, but hardened runtime and notarization remain necessary for a credible installer.

OMacOS must never bundle macOS itself. It installs only onto a user-owned Mac.

## Existing competitor

[Omachy](https://github.com/dough654/omachy) already provides an AeroSpace, SketchyBar, JankyBorders, Ghostty, Neovim, tmux, Starship, agent, backup, doctor, and uninstall setup in a Go binary. That means a dotfiles bootstrapper alone is not differentiated.

OMacOS needs to earn its place through the native Quattro-style shell, unified panels and pickers, semantic theme generation, capture and OCR, local voice, agent usage, safe and experimental window-manager adapters, signed permission onboarding, a provider contract, and tested rollback and release engineering.

## Estimated work

These are engineering estimates, not sourced facts.

| Milestone | Cumulative effort |
| --- | --- |
| Interaction prototype | 2 to 3 person-weeks |
| Installer, doctor, AeroSpace, hotkeys, minimal shell, developer stack and five themes | 10 to 15 person-weeks |
| Full native bar, panels, OSD, clipboard, reminders, capture, OCR, themes and agents | 28 to 42 person-weeks |
| Voice, audio, displays, network, all themes, plugin SDK and release channels | 43 to 66 person-weeks |
| Exhaustive manual parity, alternate WMs and broad hardware QA | 65 to 90 person-weeks |

A credible 1.0 is approximately 45 to 65 person-weeks. One engineer should expect 12 to 18 months. Two engineers with part-time design and QA could reach it in roughly 6 to 9 months.

Public-API and AeroSpace maintenance is likely 2 to 4 engineering days per month, plus 1 to 2 weeks around a major macOS release. Shipping Rift or yabai as supported profiles raises that to roughly 4 to 8 days per month and 2 to 4 weeks around a major release.

Likely breakpoints include Accessibility and WindowServer behavior, Spaces, TCC identities, notch and Stage Manager behavior, ScreenCaptureKit, CoreAudio, private media or Bluetooth integrations, Homebrew packaging, browser policies, agent schemas, DDC hardware, and signing or notarization requirements.

## Prototype acceptance criteria

Before expanding the project, the first implementation must prove:

- one AppKit bar per display
- one native command menu
- the AeroSpace adapter and the main focus, move, resize, workspace, layout, fullscreen, and scratchpad outcomes
- a Right Option Super profile that does not disturb Command or Left Option
- one semantic theme across the shell, Ghostty, borders, and AeroSpace gaps
- 100 repeated workspace and window cycles without losing a window
- sleep, wake, lid, fullscreen, and one-, two-, and three-display behavior
- permission removal and reapproval
- complete restoration of the original configuration on uninstall

Stop and reconsider the architecture if the bar remains unstable through display or fullscreen changes, AeroSpace loses windows or workspaces, no shortcut profile is comfortable for normal typing, or permission onboarding cannot be made understandable and reversible.

