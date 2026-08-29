# Supported systems

OMacOS currently targets Apple Silicon Macs.

| macOS version | Status |
| --- | --- |
| macOS Tahoe 26 | Intended production baseline |
| macOS 27 beta | Best-effort development target |
| macOS 25 and earlier | Unsupported by the installer |

The Swift shell has a macOS 14 deployment target so it can avoid accidentally depending on beta-only APIs. The installer applies the stricter product support policy.

GitHub Actions builds and runs the non-graphical suite on Apple Silicon `macos-26` and `xcode-27` runners. Physical Macs remain necessary for WindowServer, Accessibility, Input Monitoring, display, sleep, lid, notch, and fullscreen testing.

The default AeroSpace profile keeps System Integrity Protection enabled. `omacos wm profile rift` selects the experimental Rift adapter without weakening SIP. `omacos wm profile yabai` selects yabai's SIP-on feature set. OMacOS will never change SIP, edit sudoers, or load the yabai scripting addition automatically; `omacos wm power-mode guide` explains the upstream-only manual path and its security tradeoff.

Window-manager parity differs by backend:

| Outcome | AeroSpace | Rift | yabai with SIP on | yabai scripting addition |
| --- | --- | --- | --- | --- |
| Focus, move, resize, float, fullscreen | Supported | Supported | Supported | Supported |
| Ten numbered workspaces | Virtual workspaces | Virtual workspaces | User-created native Spaces | Native Spaces |
| Scratchpad | Dedicated virtual workspace | Dedicated virtual workspace | Unavailable | Supported |
| Move whole workspace to another display | Supported | Focused-window substitute | Unavailable | Supported |
| Tiles/stack layout toggle | Tiles/accordion | Traditional/stack | BSP/stack | BSP/stack |
| SIP remains fully enabled | Yes | Yes | Yes | No |

Rift's next-monitor shortcut moves the focused window because its virtual workspace model does not expose an equivalent whole-workspace operation. With SIP enabled, yabai can focus existing native Spaces but cannot create the ten-space OMacOS set; the user must create those Spaces in Mission Control first. yabai power-only commands will report an upstream error until the user has deliberately completed and loaded the scripting addition.

The shell is installed as an app bundle so macOS can present clear Microphone and Speech Recognition prompts for dictation. Development builds use ad-hoc signing. Production releases need one stable Developer ID identity and notarization; without that identity, macOS may treat an updated executable as a new privacy client and ask again.

Weather uses wttr.in with automatic IP-based location unless the user sets a city or coordinates. Media inspection is opt-in and controls Apple Music or Spotify through Apple Events, which macOS may ask the user to approve. OMacOS never attempts to bypass a privacy prompt.
