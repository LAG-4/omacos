# OMacOS

OMacOS (Omakase + MacOS) is an open-source, Omarchy-inspired environment for Apple Silicon Macs. It layers tiling, consistent shortcuts, semantic themes, a native desktop bar, developer tools, and reversible system setup onto an existing macOS installation.

This project is independent from Omarchy and 37signals. It does not distribute or modify macOS system files.

## Status

OMacOS is an implementation preview. The frozen Quattro reference has no unclassified or portable-pending entries, while physical Mac hardware validation and production signing still block a stable release. The current build includes:

- replaceable window-manager adapters: AeroSpace by default, experimental Rift, and optional yabai
- Right Option as the default physical Super key while Left Option and Command stay native
- a native Swift/AppKit bar, command menu, keybinding reference, and first system panels
- a macOS-native command menu projected from the complete frozen 328-entry Quattro reference, with Linux-only entries kept in the parity ledger instead of shown as product actions
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

Installation reports eight numbered stages and identifies the active stage if a command fails. The same install command can resume a partial run because Homebrew and OMacOS setup are idempotent. Homebrew reuses installed bundle dependencies without upgrading them. JankyBorders requires Homebrew tap trust, so the installer temporarily trusts only `felixkratz/formulae/borders` and removes that formula trust after the bundle command succeeds or fails.

The installer adds the generated OMacOS rules to the selected Karabiner profile and preserves unrelated rules. It records the original `karabiner.json` before the first managed edit. Uninstall restores that original profile.

## Default shortcuts

Hold Right Option and press:

| Shortcut | Result |
| --- | --- |
| `Super + Return` | Open Ghostty |
| `Super + Shift + Option + F` | Open Finder at the focused terminal working directory |
| `Super + Scroll` | Switch workspaces forward or backward |
| `Super + Left drag` | Move the focused window |
| `Super + Right drag` | Resize the focused window |
| `Super + G` | Create or dissolve a native window group |
| `Super + Option + Arrow` | Join the nearest directional window to the group |
| `Super + Option + Tab` | Cycle the active group |
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
| `Super + P` | Toggle the centered pseudotile substitute |
| `Super + /` | Open native display scaling controls |
| `Super + J` | Toggle split orientation |
| `Super + Shift + Backspace` | Toggle window gaps |
| `Super + Backspace` | Toggle focused-window opacity in optional yabai power mode |
| `Super + Control + Backspace` | Toggle a centered square aspect for the focused window |
| `Super + Option + ,` | Invoke the action attached to the newest OMacOS notification |
| `Super + Control + Z` | Increase native macOS accessibility zoom |
| `Super + Control + Option + Z` | Reset native macOS accessibility zoom |
| `Super + Option + [` / `]` | Resize the webcam recording overlay |
| `Super + S` | Summon the scratchpad workspace |
| `Super + Option + S` | Move a window to the scratchpad |

Karabiner-Elements treats Right Option as a dedicated OMacOS layer while held with another key. It does not turn it into the usual four-modifier Hyper chord, so `Super+Shift`, `Super+Control`, and `Super+Option` remain distinct. Pressing Right Option by itself still produces Right Option. The installer enables the supplied rules in the selected Karabiner profile automatically. `omacos setup keybindings` repairs that activation without replacing unrelated Karabiner rules.

## Commands

```bash
omacos doctor
omacos theme apply tokyo-night
omacos shell start
omacos shell toggle-menu
omacos shell toggle-panel audio
omacos shell toggle-panel keybindings
omacos capture screenshot
omacos capture recording --webcam
omacos capture text
omacos reminder add 10m "check the build"
omacos notification add Build "Finished" https://example.com/build/42
omacos notification invoke-one
omacos default set browser brave
omacos default set editor nvim
omacos launch tmux
omacos webapp install Linear https://linear.app
omacos agent usage-update
omacos weather location --set Cupertino 37.3230,-122.0322
omacos media play-pause
omacos dictation toggle
omacos zoom setup
omacos toggle toggle idle
omacos backup create before-experiment
omacos update apply
omacos channel status
omacos channel set edge
omacos channel set rc
omacos channel set dev
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
omacos bar position left
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

Focused-window transparency is available only after selecting yabai and manually enabling its scripting addition. The original `Super + Backspace` chord toggles between 78% and 100% opacity through `omacos wm transparency toggle`. AeroSpace and Rift return a direct limitation instead of changing unrelated shell transparency.

The native shell exposes command menu, keybindings, clipboard, emoji, capture, reminders, themes, backgrounds, application defaults, agent usage, system, audio, Bluetooth, network, display, calendar, power, and activity panels. The right-side bar icons and the corresponding Super shortcuts open the same panel through one stable command boundary.

The bar has purpose-built horizontal and vertical layouts, can be placed on any screen edge, and can switch between opaque and translucent rendering at runtime. OMacOS updates the AeroSpace, Rift, and yabai reserved edge when its position changes so tiled windows continue to avoid it. Panels open beside the selected edge rather than covering the bar.

Window gaps can be toggled with the original Quattro shortcut, through the command menu, or with `omacos wm gaps toggle`. The setting rewrites each managed profile consistently and preserves the 34-point bar reservation on the selected edge even when all other spacing is zero.

Legacy Quattro command-group names remain valid where the underlying outcome is portable. For example, `omacos audio`, `omacos battery`, `omacos bluetooth`, `omacos clipboard`, `omacos monitor`, `omacos power`, `omacos snapshot`, `omacos tailscale`, and `omacos wifi` route into the same native panels and service adapters instead of existing only as documentation aliases.

Clipboard history is stored locally at `~/.local/state/omacos/clipboard-history.json`, capped at 100 text entries, and skips pasteboard entries marked concealed or auto-generated. It can be cleared from its panel. OMacOS does not upload clipboard or reminder data.

OMacOS notifications can carry an optional `http`, `https`, `file`, or System Settings action URL. `Super + Option + ,` opens the action on the newest OMacOS-owned notification. macOS does not expose the actions or history of unrelated applications, so this shortcut deliberately does not claim global Notification Center control.

The installer adds one clearly marked source block to `~/.zshrc`. That block loads the OMacOS aliases, fzf/zoxide/mise/Starship initialization, compression helpers, and tmux developer layouts. Uninstall removes only that block and preserves edits made before or after installation.

Dictation uses Apple's Speech framework. Hold F9, or press `Super + Control + X` to toggle it; stopping inserts the recognized text into the focused application. The first use prompts for Microphone and Speech Recognition, and insertion needs Accessibility. When supported by the current language, recognition is required to run on-device.

Screen zoom delegates to Apple's accessibility zoom rather than capturing and redrawing the desktop. Run `omacos zoom setup` once and enable “Use keyboard shortcuts to zoom”; the original Quattro chords then send the native zoom-in command or enough zoom-out steps to return to 1×. This needs Accessibility permission and leaves the system preference under the user's control.

`Super + Shift + Option + F` walks the focused terminal process tree and opens Finder at the deepest readable working directory. It supports Ghostty, Terminal, iTerm, WezTerm, kitty, and Alacritty. macOS does not publish the active tab directory across terminal applications, so a terminal with several live tabs is best effort and reports an error instead of falling back to an unrelated folder.

Webcam recording uses a native always-on-top camera preview rather than a heavyweight recording dependency. `omacos capture recording --webcam` shows the overlay, starts the Apple region recorder with desktop and microphone audio, and removes the overlay when recording ends. The original bracket chords resize it live. Camera, Screen Recording, and Microphone approval remain explicit macOS prompts.

Pointer gestures stay inside the same Right Option ownership model as keyboard shortcuts. Karabiner consumes only Super+left/right button presses and tells the native shell when a drag starts; the shell event tap performs the Accessibility move or resize and handles Super+wheel workspace navigation. Accessibility and Input Monitoring must be approved. A tiled window may be retiled by the active manager, so floating windows provide the closest Hyprland drag behavior.

Window grouping is manager-independent. OMacOS records live Accessibility window references, aligns group members to one frame, and exposes the original toggle, directional join, remove, cycle, scroll, and index 1–5 shortcuts. Raising another member behaves like selecting a tab. Apple does not permit OMacOS to replace WindowServer decorations, so groups have no compositor-drawn tab strip and are reset when the shell restarts.

Pseudotiling uses the closest cross-manager result macOS permits: `Super + P` floats the focused window, retains its original frame, shrinks it to a centered 72% surface, and restores it on the next toggle. Unlike Hyprland, the reduced client cannot reserve an invisible compositor tile. Quattro's Style > Unlock entry is explicitly not applicable because it themes the Linux Plymouth boot-decryption prompt; Apple owns the FileVault preboot UI.

Updates take a managed snapshot before replacing files. `omacos update rollback` restores the latest one, while `omacos backup create NAME` lets you place an explicit checkpoint. The default `stable` channel installs the latest signed and notarized GitHub release; `rc` installs the newest signed prerelease. `edge` tracks current public `main`, while `dev` tracks the explicitly experimental public `dev` branch. Switching channels does not require reinstalling. Source-channel builds are ad-hoc signed. The tag workflow marks `-rc.` tags as prereleases, produces a Hardened Runtime archive, signs it with a stable Developer ID, notarizes and staples it, and publishes its checksum; the required Apple credentials are not part of the repository.

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
