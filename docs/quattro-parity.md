# Quattro parity ledger

Generated from the frozen Omarchy Quattro inventory. `implemented` means the outcome has an executable OMacOS or native macOS route; it does not claim that WindowServer behaves like Hyprland.

## Summary

| Total | Implemented | Limited | Pending | Unavailable | Not applicable |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 879 | 631 | 132 | 0 | 35 | 81 |

## Remaining portable work

| Kind | Reference | Outcome | Route |
| --- | --- | --- | --- |

## Explicit platform limits

| Kind | Reference | Outcome | Reason |
| --- | --- | --- | --- |
| binding | `default/hypr/bindings/applications.lua:5` | File manager (cwd) | The focused terminal working directory, third-party notification action, or Super+mouse compositor gesture has no safe cross-application public macOS adapter. |
| binding | `default/hypr/bindings/tiling.lua:6` | Pseudo window | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:70` | Scroll active workspace forward | Karabiner does not expose scroll-wheel input as a complex-modification source, and adding a second global input daemon would violate the single shortcut-owner design. |
| binding | `default/hypr/bindings/tiling.lua:71` | Scroll active workspace backward | Karabiner does not expose scroll-wheel input as a complex-modification source, and adding a second global input daemon would violate the single shortcut-owner design. |
| binding | `default/hypr/bindings/tiling.lua:73` | Move window | The focused terminal working directory, third-party notification action, or Super+mouse compositor gesture has no safe cross-application public macOS adapter. |
| binding | `default/hypr/bindings/tiling.lua:74` | Resize window | The focused terminal working directory, third-party notification action, or Super+mouse compositor gesture has no safe cross-application public macOS adapter. |
| binding | `default/hypr/bindings/tiling.lua:76` | Toggle window grouping | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:77` | Move active window out of group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:84` | Next window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:85` | Previous window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:87` | Move grouped window focus left | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:88` | Move grouped window focus right | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:90` | Next window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:91` | Previous window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:94` | Switch to group window  | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/utilities.lua:117` | Zoom in | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/utilities.lua:122` | Reset zoom | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/utilities.lua:19` | Toggle window transparency | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/utilities.lua:21` | Toggle single-window square aspect | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/utilities.lua:27` | Invoke last notification | The focused terminal working directory, third-party notification action, or Super+mouse compositor gesture has no safe cross-application public macOS adapter. |
| binding | `default/hypr/bindings/utilities.lua:39` | Make webcam overlay smaller | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/utilities.lua:40` | Make webcam overlay larger | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| dynamic-binding-family | `group-windows` | group windows 1 through 5 | Hyprland window groups do not have a common AeroSpace, Rift, and SIP-on yabai abstraction. |
| menu-entry | `style.bar.position.left` | Left | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `style.bar.position.right` | Right | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `style.unlock` | Unlock | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `system.hibernate` | Hibernate | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `trigger.capture.screenrecord.webcam` | With desktop + microphone audio + webcam | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `trigger.hardware.hybrid-gpu` | Hybrid GPU | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `trigger.hardware.touchscreen` | Touchscreen | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `trigger.toggle.crash-capture` | Crash Capture | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `trigger.toggle.one-window-ratio` | 1-Window Ratio | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `update.channel.dev` | Dev | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `update.channel.rc` | RC | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |
| menu-entry | `update.process.hyprsunset` | Hyprsunset | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |

The complete machine-readable ledger, including all implemented, limited, and not-applicable items, is in [`docs/quattro-parity.json`](quattro-parity.json).
