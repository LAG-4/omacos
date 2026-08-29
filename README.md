# OMacOS

OMacOS (Omakase + MacOS) is an open-source, Omarchy-inspired environment for Apple Silicon Macs. It layers tiling, consistent shortcuts, semantic themes, a native desktop bar, developer tools, and reversible system setup onto an existing macOS installation.

This project is independent from Omarchy and 37signals. It does not distribute or modify macOS system files.

## Status

OMacOS is at its first prototype milestone. The current build includes:

- AeroSpace tiling with Omarchy-style window and workspace bindings
- Right Option as the default physical Super key while Left Option and Command stay native
- a native Swift/AppKit bar, command menu, keybinding reference, and first system panels
- clipboard history, emoji, reminders, capture, on-device OCR, background, and system panels
- all 22 frozen Quattro semantic themes with generated shell, terminal, TUI, editor, tmux, and border targets
- configurable terminal, browser, and editor defaults plus Omarchy-style shell tools, tmux layouts, and a self-contained Neovim profile
- local web-app bundles and a native agent-usage panel backed by Claude, Codex, and Fireworks collectors
- weather and media panels, Quattro-style date/battery/weather notices, reversible stay-awake and bar toggles, and native on-device dictation
- managed snapshots, versioned migrations, tested updates, and one-command rollback
- a readable installer with dry-run, doctor, backup, and uninstall commands
- macOS 26 compatibility checks and macOS 27 beta test coverage

Do not install this on a primary machine yet. Use the dry run first and read the printed plan.

## Try the local checkout

```bash
./install.sh --dry-run
swift run omacos-shell
```

When the first public installer is tagged, installation will use one command:

```bash
curl -fsSL https://raw.githubusercontent.com/LAG-4/omacos/main/install.sh | zsh
```

The bootstrap script downloads this repository, prints every planned change, requests confirmation, and delegates to the versioned installer. It does not bypass macOS permission dialogs.

## Default shortcuts

Hold Right Option and press:

| Shortcut | Result |
| --- | --- |
| `Super + Return` | Open Ghostty |
| `Super + Space` | Toggle the OMacOS command menu |
| `Super + W` or `Super + Q` | Close the focused window |
| `Super + Arrow` | Focus in a direction |
| `Super + Shift + Arrow` | Move a window in a direction |
| `Super + 1...9` | Switch workspace |
| `Super + Shift + 1...9` | Move a window to workspace |
| `Super + T` | Toggle floating and tiling |
| `Super + F` | Toggle fullscreen |
| `Super + J` | Toggle split orientation |
| `Super + S` | Summon the scratchpad workspace |
| `Super + Shift + S` | Move a window to the scratchpad |

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
omacos uninstall
```

The native shell exposes command menu, keybindings, clipboard, emoji, capture, reminders, themes, backgrounds, application defaults, agent usage, system, audio, Bluetooth, network, display, calendar, power, and activity panels. The right-side bar icons and the corresponding Super shortcuts open the same panel through one stable command boundary.

Clipboard history is stored locally at `~/.local/state/omacos/clipboard-history.json`, capped at 100 text entries, and skips pasteboard entries marked concealed or auto-generated. It can be cleared from its panel. OMacOS does not upload clipboard or reminder data.

The installer adds one clearly marked source block to `~/.zshrc`. That block loads the OMacOS aliases, fzf/zoxide/mise/Starship initialization, compression helpers, and tmux developer layouts. Uninstall removes only that block and preserves edits made before or after installation.

Dictation uses Apple's Speech framework. Hold F9, or press `Super + Control + X` to toggle it; stopping inserts the recognized text into the focused application. The first use prompts for Microphone and Speech Recognition, and insertion needs Accessibility. When supported by the current language, recognition is required to run on-device.

Updates take a managed snapshot before replacing files. `omacos update rollback` restores the latest one, while `omacos backup create NAME` lets you place an explicit checkpoint. Development builds are ad-hoc signed; stable releases still require a consistent Developer ID signature and notarization so privacy permissions survive upgrades reliably.

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

See [the implementation roadmap](docs/roadmap.md) and [the research report](docs/research.md) for the intended scope and known macOS limits. The source-complete [frozen Quattro inventory](docs/quattro-inventory.json) tracks every manual chapter, plugin manifest, CLI group, default binding declaration, menu entry, and package from the reference commit.

## License

OMacOS code is MIT licensed. Third-party applications retain their own licenses. Theme assets, wallpapers, fonts, and icons require an individual license review before release packaging. See [third-party notices](THIRD_PARTY_NOTICES.md) for the Omarchy attribution and retained license.
