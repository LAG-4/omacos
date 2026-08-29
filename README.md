# OMacOS

OMacOS (Omakase + MacOS) is an open-source, Omarchy-inspired environment for Apple Silicon Macs. It layers tiling, consistent shortcuts, semantic themes, a native desktop bar, developer tools, and reversible system setup onto an existing macOS installation.

This project is independent from Omarchy and 37signals. It does not distribute or modify macOS system files.

## Status

OMacOS is at its first prototype milestone. The current build includes:

- AeroSpace tiling with Omarchy-style window and workspace bindings
- Right Option as the default physical Super key while Left Option and Command stay native
- a native Swift/AppKit bar and command menu on every display
- a Tokyo Night semantic theme for the shell, Ghostty, and JankyBorders
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
omacos uninstall
```

To undo a completed installation from any terminal:

```bash
omacos uninstall
```

To stop a shell launched locally with `swift run omacos-shell`, run this from the repository:

```bash
./uninstall.sh
```

The local command stops the debug shell. It leaves `.build` in the repository because that directory is only a Swift compilation cache and does not change macOS.

See [the implementation roadmap](docs/roadmap.md) and [the research report](docs/research.md) for the intended scope and known macOS limits.

## License

OMacOS code is MIT licensed. Third-party applications retain their own licenses. Theme assets, wallpapers, fonts, and icons require an individual license review before release packaging. See [third-party notices](THIRD_PARTY_NOTICES.md) for the Omarchy attribution and retained license.
