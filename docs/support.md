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

The shell is installed as an app bundle so macOS can present clear Microphone and Speech Recognition prompts for dictation. Development builds use ad-hoc signing. Production releases need one stable Developer ID identity and notarization; without that identity, macOS may treat an updated executable as a new privacy client and ask again.

Weather uses wttr.in with automatic IP-based location unless the user sets a city or coordinates. Media inspection is opt-in and controls Apple Music or Spotify through Apple Events, which macOS may ask the user to approve. OMacOS never attempts to bypass a privacy prompt.
