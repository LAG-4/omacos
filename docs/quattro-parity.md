# Quattro parity ledger

Generated from the frozen Omarchy Quattro inventory. `implemented` means the outcome has an executable OMacOS or native macOS route; it does not claim that WindowServer behaves like Hyprland.

## Summary

| Total | Implemented | Limited | Pending | Unavailable | Not applicable |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 879 | 641 | 142 | 0 | 12 | 84 |

## Remaining portable work

| Kind | Reference | Outcome | Route |
| --- | --- | --- | --- |

## Explicit platform limits

| Kind | Reference | Outcome | Reason |
| --- | --- | --- | --- |
| binding | `default/hypr/bindings/tiling.lua:6` | Pseudo window | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:76` | Toggle window grouping | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:77` | Move active window out of group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:84` | Next window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:85` | Previous window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:87` | Move grouped window focus left | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:88` | Move grouped window focus right | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:90` | Next window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:91` | Previous window in group | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| binding | `default/hypr/bindings/tiling.lua:94` | Switch to group window  | This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent. |
| dynamic-binding-family | `group-windows` | group windows 1 through 5 | Hyprland window groups do not have a common AeroSpace, Rift, and SIP-on yabai abstraction. |
| menu-entry | `style.unlock` | Unlock | The command returns an explicit macOS platform limitation instead of silently doing the wrong thing. |

The complete machine-readable ledger, including all implemented, limited, and not-applicable items, is in [`docs/quattro-parity.json`](quattro-parity.json).
