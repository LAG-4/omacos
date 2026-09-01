# Testing OMacOS without turning the development Mac into the test fixture

OMacOS uses four verification layers because no single macOS test environment covers package lifecycle, privacy permissions, physical displays, input devices, and visual fidelity.

## 1. Fast checkout tests

Run `./test/all`. These tests build the native shell and exercise configuration generation, package provenance, install and uninstall restoration, AeroSpace login state, keybinding projection, window-manager adapters, themes, menus, and utility commands with isolated homes and fake system tools. They do not alter the logged-in desktop.

## 2. Disposable macOS 27 VM

The VM driver uses [Tart](https://github.com/openai/tart) on Apple's Virtualization.framework. It creates one reusable clean macOS 27 base and a disposable stacked clone for each run. The clone receives the current checkout, including uncommitted changes. The guest establishes Ghostty and AeroSpace as pre-existing applications, installs OMacOS, runs its diagnostics, uninstalls with package cleanup, and verifies that the two pre-existing applications, the exact AeroSpace config, its disabled login state, and its stopped process state survive.

Install Tart with `brew install openai/tools/tart`, then run:

```zsh
./scripts/macos-vm-test.zsh doctor
./scripts/macos-vm-test.zsh prepare
./scripts/macos-vm-test.zsh run
```

The same commands are available from an installed checkout as `omacos qa vm doctor`, `omacos qa vm prepare`, and `omacos qa vm run`.

The driver requires at least 70 GiB of free VM storage. `TART_HOME` may point to a fast external APFS volume. A base VM is intentionally kept between runs; disposable clones are deleted only after a passing lifecycle. A failed clone is stopped and retained for inspection. `./scripts/macos-vm-test.zsh clean` removes only the explicitly named `omacos-macos27-test` clone and refuses names outside the `omacos-macos27-*` namespace.

## 3. Deterministic visual fixtures

The native shell consumes `omarchy-shell-contract.json`, frozen to the recorded Quattro commit. Geometry and source-contract tests catch changes to bar dimensions, menu dimensions, typography, spacing, layout slots, state opacities, and animation durations. Release candidates should additionally capture the menu, every panel, and horizontal and vertical bars at 1x and 2x scale and compare them with reviewed golden images.

## 4. Guarded hardware smoke test

Apple's VM does not reproduce a real two- or three-display arrangement, lid and notch behavior, system privacy approvals, global Right Option input, camera and microphone capture, sleep, or the exact WindowServer behavior of the development Mac. Those checks remain a short hardware matrix after the VM passes. Capture the pre-test package and login-item report, apply OMacOS, run `docs/hardware-validation.md`, and uninstall without package removal. The package-provenance and AeroSpace-lifecycle records provide the before/after evidence; do not remove Homebrew packages unless the report says OMacOS introduced them.

On this development Mac, the VM is currently the right next step only after freeing storage or moving `TART_HOME`: a macOS restore image, base disk, and disposable overlay should not be attempted with less than the driver's 70 GiB safety floor.
