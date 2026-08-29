# OMacOS

OMacOS (Omakase + MacOS) is an open-source, Omarchy-inspired environment for Apple Silicon Macs. It layers tiling, consistent shortcuts, semantic themes, a native desktop bar, developer tools, and reversible system setup onto an existing macOS installation.

This project is independent from Omarchy and 37signals. It does not distribute or modify macOS system files.

## Status

OMacOS is an implementation preview. The frozen Quattro reference has no unclassified or portable-pending entries, while physical Mac hardware validation and production signing still block a stable release. The current build includes:

- replaceable window-manager adapters: AeroSpace by default, experimental Rift, and optional yabai
- Right Option as the default physical Super key while Left Option and Command stay native
- a native Swift/AppKit bar, command menu, keybinding reference, and first system panels
- the complete frozen 328-entry Quattro menu hierarchy with global search, macOS action adapters, and explicit Linux-only limitations
- clipboard history, emoji, reminders, capture, on-device OCR, background, and system panels
- all 22 frozen Quattro semantic themes with generated shell, terminal, TUI, editor, tmux, and border targets
- configurable terminal, browser, and editor defaults plus Omarchy-style shell tools, tmux layouts, and a self-contained Neovim profile
- local web-app bundles and a native agent-usage panel backed by Claude, Codex, and Fireworks collectors
- weather and media panels, Quattro-style date/battery/weather notices, reversible stay-awake and bar toggles, and native on-device dictation
- managed snapshots, versioned migrations, tested updates, and one-command rollback
- locally generated Wi-Fi sharing QR codes, network and disk benchmarks, optional Tailscale and Dropbox panels, and an explicit optional-app catalog
- QR capture with on-device Vision recognition, system-audio screen recording, native AirDrop handoff, local media transcoding, and Homebrew-backed font choices
- a complete 29-plugin Quattro parity catalog plus an isolated out-of-process provider contract
- a machine-checked 879-item parity ledger with explicit macOS limitations and no portable-pending entries
- native themed OSD and developer-gallery panels, native focused-window width save/restore, and a safe Accessibility-backed close-all action
- a readable installer with dry-run, doctor, backup, and uninstall commands
- permission diagnostics, privacy-safe hardware reports, a physical validation matrix, and signed/notarized release packaging
- macOS 26 compatibility checks and macOS 27 beta test coverage

Do not install this on a primary machine yet. Use the dry run first and read the printed plan.

## Try the local checkout

```bash
./install.sh --dry-run
swift run omacos-shell
```

Installation uses one command:

```bash
curl -fsSL https://raw.githubusercontent.com/LAG-4/omacos/main/install.sh | zsh
```

The bootstrap prefers the latest signed, notarized release, verifies its checksum, bundle identity, code signature, and Gatekeeper acceptance, then pairs it with source from the same immutable tag. Before the first public tag, or when GitHub has no valid release, it falls back to building the current `main` source. Both paths print every planned change and request confirmation through the terminal even when the script itself arrived through a pipe. They do not bypass macOS permission dialogs.

## Default shortcuts

Hold Right Option and press:

| Shortcut | Result |
| --- | --- |
| `Super + Return` | Open Ghostty |
| `Super + Space` | Toggle the OMacOS command menu |
| `Super + W` or `Super + Q` | Close the focused window |
| `Super + Arrow` | Focus in a direction |
| `Super + Shift + Arrow` | Move a window in a direction |
| `Super + 1...0` | Switch among workspaces 1–10 |
| `Super + Shift + 1...0` | Move a window to workspace and follow it |
| `Super + Shift + Option + 1...0` | Move a window silently to workspace |
| `Super + T` | Toggle floating and tiling |
| `Super + F` | Toggle fullscreen |
| `Super + Control + F` | Toggle tiled fullscreen |
| `Super + Option + F` | Toggle full-width geometry |
| `Super + O` | Float the focused window; pinning needs optional yabai power mode |
| `Super + /` | Open native display scaling controls |
| `Super + J` | Toggle split orientation |
| `Super + Shift + Backspace` | Toggle window gaps |
| `Super + Control + Backspace` | Toggle a centered square aspect for the focused window |
| `Super + S` | Summon the scratchpad workspace |
| `Super + Option + S` | Move a window to the scratchpad |

Karabiner-Elements treats Right Option as a dedicated OMacOS layer while held with another key. It does not turn it into the usual four-modifier Hyper chord, so `Super+Shift`, `Super+Control`, and `Super+Option` remain distinct. Pressing Right Option by itself still produces Right Option. Enable the supplied "OMacOS Super key" rule after installation.

## Commands

```bash
omacos doctor
omacos theme apply tokyo-night
omacos shell start
omacos shell toggle-menu
omacos shell toggle-panel audio
omacos shell toggle-panel keybindings
omacos capture screenshot
omacos capture text
omacos reminder add 10m "check the build"
omacos default set browser brave
omacos default set editor nvim
omacos launch tmux
omacos webapp install Linear https://linear.app
omacos agent usage-update
omacos weather location --set Cupertino 37.3230,-122.0322
omacos media play-pause
omacos dictation toggle
omacos toggle toggle idle
omacos backup create before-experiment
omacos update apply
omacos channel status
omacos channel set edge
omacos package list gaming
omacos package install utm
omacos plugin show
omacos wm status
omacos parity summary
omacos parity list unavailable
omacos shell toggle-panel dev-gallery
omacos osd
omacos permissions status
omacos permissions open accessibility
omacos qa report hardware.json
omacos audio status
omacos bluetooth show
omacos clipboard list
omacos monitor show
omacos power show
omacos snapshot list
omacos bar position bottom
omacos bar transparency toggle
omacos uninstall
```

All Right Option window and workspace shortcuts go through one stable OMacOS command surface. AeroSpace is installed and selected by default. Rift adds animated layouts and virtual workspaces while keeping SIP enabled, but remains experimental because it uses undocumented macOS APIs. yabai is also available in a reduced SIP-on mode:

```bash
omacos wm profile
omacos wm profile rift
omacos wm profile yabai
omacos wm profile aerospace
```

OMacOS does not weaken SIP, edit sudoers, or load yabai's scripting addition. `omacos wm power-mode guide` explains the separate upstream process and its security tradeoff. Uninstall restores Rift and yabai configuration files that existed before OMacOS first managed them.

The native shell exposes command menu, keybindings, clipboard, emoji, capture, reminders, themes, backgrounds, application defaults, agent usage, system, audio, Bluetooth, network, display, calendar, power, and activity panels. The right-side bar icons and the corresponding Super shortcuts open the same panel through one stable command boundary.

The horizontal bar can be placed at the top or bottom and switched between opaque and translucent rendering at runtime. OMacOS updates the active AeroSpace, Rift, or yabai reserved edge when its position changes so tiled windows continue to avoid it. Left and right bar positions remain explicit limitations because they require a separate vertical widget layout rather than rotating the Quattro design.

Window gaps can be toggled with the original Quattro shortcut, through the command menu, or with `omacos wm gaps toggle`. The setting rewrites each managed profile consistently and preserves the 34-point bar reservation on the selected edge even when all other spacing is zero.

Legacy Quattro command-group names remain valid where the underlying outcome is portable. For example, `omacos audio`, `omacos battery`, `omacos bluetooth`, `omacos clipboard`, `omacos monitor`, `omacos power`, `omacos snapshot`, `omacos tailscale`, and `omacos wifi` route into the same native panels and service adapters instead of existing only as documentation aliases.

Clipboard history is stored locally at `~/.local/state/omacos/clipboard-history.json`, capped at 100 text entries, and skips pasteboard entries marked concealed or auto-generated. It can be cleared from its panel. OMacOS does not upload clipboard or reminder data.

The installer adds one clearly marked source block to `~/.zshrc`. That block loads the OMacOS aliases, fzf/zoxide/mise/Starship initialization, compression helpers, and tmux developer layouts. Uninstall removes only that block and preserves edits made before or after installation.

Dictation uses Apple's Speech framework. Hold F9, or press `Super + Control + X` to toggle it; stopping inserts the recognized text into the focused application. The first use prompts for Microphone and Speech Recognition, and insertion needs Accessibility. When supported by the current language, recognition is required to run on-device.

Updates take a managed snapshot before replacing files. `omacos update rollback` restores the latest one, while `omacos backup create NAME` lets you place an explicit checkpoint. The default `stable` channel installs the latest signed and notarized GitHub tag. `omacos channel set edge` opts into builds from the current public `main` source; switching back with `omacos channel set stable` does not require reinstalling. Development builds are ad-hoc signed. The tag workflow produces a Hardened Runtime archive, signs it with a stable Developer ID, notarizes and staples it, and publishes its checksum; the required Apple credentials are not part of the repository.

The base install remains deliberately focused. Browsers, GUI development tools, communication apps, media tools, utilities, gaming clients, and virtual-machine apps live in the Optional Apps panel and `omacos package`; choosing Install is the authorization for that one Homebrew cask. OMacOS does not remove those third-party apps during its own uninstall.

The Quattro Plugins panel reports the actual macOS implementation and limitation for every frozen plugin. External plugins are never loaded into the shell process; the versioned contract in [docs/plugin-provider.md](docs/plugin-provider.md) executes providers separately and validates their JSON response.

For local visual development, run a panel directly without installing the project:

```bash
swift run omacos-shell --preview-panel audio
```

Stop it with Control-C; preview mode does not write system configuration.

To undo a completed installation from any terminal:

```bash
omacos uninstall
```

To stop a shell launched locally with `swift run omacos-shell`, run this from the repository:

```bash
./uninstall.sh
```

The local command stops the debug shell. It leaves `.build` in the repository because that directory is only a Swift compilation cache and does not change macOS.

See [the implementation roadmap](docs/roadmap.md), [research report](docs/research.md), [release guide](docs/releasing.md), and [hardware validation matrix](docs/hardware-validation.md) for the intended scope and known macOS limits. The source-complete [frozen Quattro inventory](docs/quattro-inventory.json) tracks every manual chapter, plugin manifest, CLI group, default binding declaration, menu entry, and package from the reference commit. The generated [Quattro parity ledger](docs/quattro-parity.md) gives every one of those 879 items an executable route, deliberate limitation, explicit impossibility, or not-applicable decision.

## License

OMacOS code is MIT licensed. Third-party applications retain their own licenses. Theme assets, wallpapers, fonts, and icons require an individual license review before release packaging. See [third-party notices](THIRD_PARTY_NOTICES.md) for the Omarchy attribution and retained license.
