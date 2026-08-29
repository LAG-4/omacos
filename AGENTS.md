# OMacOS contributor guide

OMacOS is an independent, Omarchy-inspired macOS environment. It customizes an existing macOS installation and never redistributes macOS.

## Product constraints

- Keep SIP enabled in the default installation.
- Support Apple Silicon on the current stable macOS release. Treat macOS betas as best effort until promoted in `docs/support.md`.
- Preserve Command and Left Option behavior. The default Super key is a dedicated Right Option layer implemented by Karabiner-Elements.
- Every system change needs a dry-run explanation, a backup, and a reversible uninstall path.
- Never silently approve Accessibility, Screen Recording, Microphone, or other TCC permissions.
- Keep window manager, hotkey, theme, and macOS service integrations behind replaceable adapters.

## Code conventions

- Use searchable domain names such as `OMacOSWorkspaceMonitor`, not generic names such as `Manager`.
- Keep one concept in each source file and colocate its tests.
- Use `#!/bin/zsh` for macOS scripts and `set -euo pipefail` for commands that mutate state.
- Run `swift build` and `./test/all` before committing. Add XCTest coverage when the test host has a full Xcode installation; macOS 27 Command Line Tools alone do not ship the required test frameworks.
- Do not hard-code a developer home directory. Tests must redirect writes through `OMACOS_TEST_HOME`.
