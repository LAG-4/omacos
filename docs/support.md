# Supported systems

OMacOS currently targets Apple Silicon Macs.

| macOS version | Status |
| --- | --- |
| macOS Tahoe 26 | Intended production baseline |
| macOS 27 beta | Best-effort development target |
| macOS 25 and earlier | Unsupported by the installer |

The Swift shell has a macOS 14 deployment target so it can avoid accidentally depending on beta-only APIs. The installer applies the stricter product support policy.

GitHub Actions builds and runs the non-graphical suite on Apple Silicon `macos-26` and `xcode-27` runners. Physical Macs remain necessary for WindowServer, Accessibility, Input Monitoring, display, sleep, lid, notch, and fullscreen testing.

The default profile keeps System Integrity Protection enabled. An optional yabai power profile may be added later, but it will remain isolated from the normal installation.
