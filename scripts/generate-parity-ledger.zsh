#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
inventory_path=${1:-$project_root/docs/quattro-inventory.json}
output_path=${2:-$project_root/docs/quattro-parity.json}
markdown_path=${3:-$project_root/docs/quattro-parity.md}
keybindings_path="$project_root/config/keybindings.json"

if [[ ! -f $inventory_path ]]; then
  print -u2 "Quattro inventory not found: $inventory_path"
  exit 1
fi

temporary_path=$(mktemp -t omacos-parity.XXXXXX)
trap 'rm -f "$temporary_path"' EXIT

jq --slurpfile keys "$keybindings_path" '
  def parity($kind; $id; $title; $status; $grade; $route; $notes; $source):
    {
      kind: $kind,
      id: $id,
      title: $title,
      implementationStatus: $status,
      grade: $grade,
      route: $route,
      notes: $notes,
      source: $source
    };

  def in_list($value; $values): $values | index($value) != null;

  def manual_parity:
    . as $item
    | if in_list($item.id; [
        "44-mac-support", "49-omarchy-on", "50-dual-boot-install"
      ]) then
        parity("manual"; $item.id; $item.title; "not-applicable"; "not-applicable"; "docs/quattro-parity.md"; "The Arch or Linux installation scenario does not apply to a rice installed on an existing Mac."; $item.file)
      elif in_list($item.id; [
        "26-gaming", "27-filling-out-pdfs", "28-windows-vm", "37-hardware-authentication", "41-branding"
      ]) then
        parity("manual"; $item.id; $item.title; "limited"; "native-replacement"; "omacos menu"; "The outcome uses macOS applications or protected Apple UI and cannot reproduce the Linux implementation one-to-one."; $item.file)
      else
        parity("manual"; $item.id; $item.title; "implemented"; "close-substitute"; "omacos help / native shell"; "The user-facing workflow has an OMacOS implementation or a documented macOS-native replacement."; $item.file)
      end;

  def plugin_parity:
    . as $item
    | if in_list($item.id; ["omarchy.lock", "omarchy.polkit"]) then
        parity("plugin"; $item.id; $item.name; "implemented"; "native-replacement"; "Apple security UI"; "macOS owns the trusted authentication surface; OMacOS hands off to it."; $item.source)
      elif in_list($item.id; ["omarchy.notifications", "omarchy.audio", "omarchy.bluetooth", "omarchy.monitor", "omarchy.media", "omarchy.nightlight"]) then
        parity("plugin"; $item.id; $item.name; "limited"; "close-substitute"; "native shell panel"; "Public macOS APIs expose the main workflow but not every Linux service or global system capability."; $item.source)
      else
        parity("plugin"; $item.id; $item.name; "implemented"; "close-substitute"; "native shell panel or service"; "The Quattro-owned outcome is implemented through the native shell or an OMacOS service adapter."; $item.source)
      end;

  def cli_parity:
    . as $item
    | if in_list($item.id; ["drive", "finalize", "hibernation", "hyprland", "plymouth", "sudo", "windows"]) then
        parity("cli-group"; $item.id; $item.description; "not-applicable"; "not-applicable"; "docs/quattro-parity.md"; "This group controls an Arch, bootloader, Hyprland, drive-encryption, or Linux session concern not owned by a macOS rice."; "bin/omarchy")
      elif in_list($item.id; ["brightness", "crash", "display", "dns", "hw", "osd", "powerprofiles", "refresh", "reinstall", "tui", "voxtype"]) then
        parity("cli-group"; $item.id; $item.description; "limited"; "native-replacement"; "omacos menu / System Settings"; "OMacOS implements the supported outcome or opens the protected macOS control; some Linux-specific subcommands do not translate."; "bin/omarchy")
      elif $item.id == "channel" then
        parity("cli-group"; $item.id; $item.description; "implemented"; "close-substitute"; "omacos channel"; "Stable installs signed tags and edge tracks public main source, with channel changes included in managed snapshots."; "bin/omarchy")
      elif in_list($item.id; ["ascii", "branch", "file", "hook", "installed", "mise", "pkg", "restart", "screensaver", "version"] ) then
        parity("cli-group"; $item.id; $item.description; "implemented"; "close-substitute"; ("omacos " + $item.id); "The portable command group is exposed through the OMacOS CLI."; "bin/omarchy")
      else
        parity("cli-group"; $item.id; $item.description; "implemented"; "close-substitute"; ("omacos " + $item.id); "The group outcome is available directly or through the native command menu and service adapters."; "bin/omarchy")
      end;

  def binding_title:
    . as $item
    | ((.declaration | try capture("o\\.bind(?:_toggle)?\\([^,]+,\\s*\\\"(?<label>[^\\\"]*)\\\"").label catch "") // "") as $label
    | if ($label | length) > 0 then $label else ("Binding at line " + ($item.line | tostring)) end;

  def binding_parity:
    . as $item
    | (binding_title) as $title
    | ([ $keys[0].bindings[].description, ($keys[0].globalBindings // [])[].description ] | index($title) != null) as $isBound
    | if $isBound and $title == "Invoke last notification" then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "limited"; "close-substitute"; "omacos notification invoke-one"; "The shortcut invokes an action URL attached to the newest OMacOS notification; Apple does not expose actions owned by third-party Notification Center entries."; $item.source)
      elif $isBound and $title == "File manager (cwd)" then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "limited"; "close-substitute"; "omacos launch files-cwd"; "OMacOS resolves the deepest descendant working directory for supported focused terminals and opens Finder there. macOS does not expose the focused tab directory directly, so multi-tab terminal selection is best effort."; $item.source)
      elif $isBound and $title == "Toggle window transparency" then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "limited"; "optional-unsafe"; "omacos wm transparency toggle"; "The original shortcut controls focused-window opacity in manually enabled yabai power mode; AeroSpace and Rift have no equivalent compositor-opacity API."; $item.source)
      elif $isBound and $title == "Toggle single-window square aspect" then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "native-replacement"; "omacos wm square-aspect-toggle"; "Accessibility resizes the focused window to a centered square and restores its saved frame on the next invocation."; $item.source)
      elif $isBound and ($title == "Zoom in" or $title == "Reset zoom") then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "limited"; "native-replacement"; ("omacos zoom " + (if $title == "Zoom in" then "in" else "reset" end)); "The original chord drives the supported macOS accessibility zoom shortcuts. The user must enable keyboard zoom in System Settings; OMacOS does not silently change accessibility preferences."; $item.source)
      elif $isBound and ($title | test("^Make webcam overlay")) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "native-replacement"; "omacos capture webcam smaller/larger"; "The original chords resize the native camera preview overlay while recording."; $item.source)
      elif $isBound and ($title | test("^Monitor scaling")) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "native-replacement"; "native display panel"; "The original chord opens display resolution controls because macOS does not expose a supported global scale-step API."; $item.source)
      elif $isBound and $title == "Pop window out (float & pin)" then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "limited"; "optional-unsafe"; "omacos wm pop-window"; "The safe path floats the window on every profile. Global pinning requires the manually enabled yabai scripting addition."; $item.source)
      elif $isBound then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "close-substitute"; "config/keybindings.json"; "Right Option dispatches the matching outcome through Karabiner and an OMacOS adapter."; $item.source)
      elif ($item.source == "default/hypr/bindings/tiling.lua" and ($item.line == 23 or $item.line == 24 or $item.line == 25))
        or ($item.source == "default/hypr/bindings/utilities.lua" and $item.line == 110) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "close-substitute"; "config/keybindings.json"; "This declaration expands into a dynamic family covered by generated workspace or native bar routes."; $item.source)
      elif $title == "Omarchy menu" then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "exact"; "omacos shell toggle-menu"; "The product keeps its own OMacOS name while preserving the shortcut and menu outcome."; $item.source)
      elif $item.source | endswith("/media.lua") then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "native-replacement"; "macOS media and hardware keys"; "macOS handles this hardware key globally; OMacOS does not intercept it."; $item.source)
      elif in_list($title; ["Reveal active window on top", "Power menu"]) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "native-replacement"; "macOS window and power UI"; "macOS provides the equivalent system-owned behavior without an OMacOS interception."; $item.source)
      elif ($title | test("^(Expand window|Shrink window)")) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "close-substitute"; "omacos wm resize-grow / resize-shrink"; "All window-manager profiles expose smart resizing, although their exact pixel anchoring differs from Hyprland."; $item.source)
      elif in_list($title; ["Invoke last notification", "Move window", "Resize window"]) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "unavailable"; "impossible"; "docs/quattro-parity.md"; "The focused terminal working directory, third-party notification action, or Super+mouse compositor gesture has no safe cross-application public macOS adapter."; $item.source)
      elif in_list($title; ["Scroll active workspace forward", "Scroll active workspace backward"]) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "unavailable"; "impossible"; "docs/quattro-parity.md"; "Karabiner does not expose scroll-wheel input as a complex-modification source, and adding a second global input daemon would violate the single shortcut-owner design."; $item.source)
      elif $item.source | endswith("/voxtype.lua") then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "close-substitute"; "F9 native dictation binding"; "The press and release declarations are represented by one Karabiner key-down/key-up manipulator backed by Speech.framework."; $item.source)
      elif ($item.declaration | test("Pseudo|group|transparency|gaps|square aspect|webcam|Monitor scaling|Tiled full screen|Full width|Pop window|Zoom"; "i")) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "unavailable"; "impossible"; "docs/quattro-parity.md"; "This outcome depends on Hyprland compositor or grouping behavior with no common SIP-on macOS equivalent."; $item.source)
      elif ($item.declaration | test("Lid Switch|touchpad|laptop display|mirroring"; "i")) then
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "implemented"; "native-replacement"; "macOS power and display policy"; "macOS owns this hardware event and applies its protected system policy."; $item.source)
      else
        parity("binding"; ($item.source + ":" + ($item.line | tostring)); $title; "pending"; "close-substitute"; "config/keybindings.json"; "The outcome is portable but is not yet represented in the generated Right Option profile."; $item.source)
      end;

  def dynamic_binding_parity:
    . as $item
    | if $item.id == "workspaces" then
        parity("dynamic-binding-family"; $item.id; $item.expansion; "implemented"; "close-substitute"; "config/keybindings.json"; "All ten focus, move-and-follow, and silent-move chords are generated."; $item.source)
      elif $item.id == "bar-panels" then
        parity("dynamic-binding-family"; $item.id; $item.expansion; "implemented"; "close-substitute"; "native bar"; "The bar exposes the corresponding panels as clickable native widgets and named shortcut routes."; $item.source)
      else
        parity("dynamic-binding-family"; $item.id; $item.expansion; "unavailable"; "impossible"; "docs/quattro-parity.md"; "Hyprland window groups do not have a common AeroSpace, Rift, and SIP-on yabai abstraction."; $item.source)
      end;

  def menu_parity:
    . as $item
    | if $item.referenceKind != "action" then
        parity("menu-entry"; $item.id; $item.label; "implemented"; "exact"; "omacos shell toggle-menu"; "The native searchable command menu preserves this hierarchy."; "default/omarchy/omarchy-menu.jsonc")
      elif in_list($item.id; ["system.hibernate", "trigger.hardware.hybrid-gpu", "trigger.hardware.touchscreen"]) then
        parity("menu-entry"; $item.id; $item.label; "not-applicable"; "not-applicable"; "macOS system policy"; "The supported Apple Silicon Macs do not expose this Linux hardware or power-policy control."; "default/omarchy/omarchy-menu.jsonc")
      elif $item.id == "trigger.toggle.crash-capture" then
        parity("menu-entry"; $item.id; $item.label; "limited"; "native-replacement"; "Console.app"; "macOS owns crash collection; OMacOS opens the system crash-report browser instead of replacing that pipeline."; "default/omarchy/omarchy-menu.jsonc")
      elif $item.id == "trigger.capture.screenrecord.webcam" then
        parity("menu-entry"; $item.id; $item.label; "implemented"; "native-replacement"; "omacos capture recording --webcam"; "The native camera preview is captured visibly with the selected desktop region plus system and microphone audio."; "default/omarchy/omarchy-menu.jsonc")
      elif ($item.id | test("^(style\\.bar\\.position\\.(left|right)|style\\.unlock|update\\.channel\\.(rc|dev))")) then
        parity("menu-entry"; $item.id; $item.label; "unavailable"; "impossible"; "omacos menu run"; "The command returns an explicit macOS platform limitation instead of silently doing the wrong thing."; "default/omarchy/omarchy-menu.jsonc")
      elif ($item.id | test("^(apps$|about$|system\\.|learn\\.|trigger\\.(emoji|reminder|capture\\.(screenshot|text|color|qr|screenrecord\\.(no-audio|desktop-audio|microphone|stop))|transcode|share($|\\.)|toggle\\.(idle-lock|notifications|nightlight|top-bar|window-gaps|one-window-ratio|workspace-layout|battery-percentage|screensaver)|hardware($|\\.(laptop-display|mirror-display|touchpad($|\\.)|touchpad-haptics($|\\.)))|tests\\.(network-speedtest|disk-speedtest))|style\\.(theme|background|font|bar($|\\.(position\\.(top|bottom)|transparency))|hyprland|screensaver($|\\.)|about($|\\.))|setup\\.(monitors|keybindings|input|network($|\\.)|default($|\\.)|plugin($|\\.)|security($|\\.)|config($|\\.)|direct-boot|reset)|install($|\\.)|remove($|\\.)|update($|\\.(omarchy|channel($|\\.(stable|edge))|config($|\\.)|themes|process\\.(shell|hyprsunset)|hardware($|\\.)|firmware|password($|\\.)|timezone|time)))")) then
        parity("menu-entry"; $item.id; $item.label; "implemented"; "close-substitute"; "omacos menu run"; "The entry routes to an OMacOS workflow, native panel, application, or System Settings."; "default/omarchy/omarchy-menu.jsonc")
      else
        parity("menu-entry"; $item.id; $item.label; "pending"; "close-substitute"; "omacos menu run"; "This portable or application-specific leaf still needs a dedicated macOS adapter."; "default/omarchy/omarchy-menu.jsonc")
      end;

  def package_parity:
    . as $item
    | if ($item.name | test("^(base|base-devel|linux($|-)|linux-firmware|linux-headers|linux-ptl|linux-t2|hyprland|quickshell|uwsm|sddm|plymouth|limine|pacman-contrib|yay|zram-generator|pipewire|wireplumber|alsa-utils|bluez|networkmanager|ufw|dkms|btrfs-progs|sof-firmware|vulkan-|nvidia-|lib32-nvidia|intel-|apple-|dell-|tuxedo-|yt6801|qmk-hid|asdcontrol|asusctl|t2fanrd|kernel-modules-hook|xdg-desktop-portal|qt6-wayland|gtk4-layer-shell|libpulse|broadcom-wl|thermald|power-profiles-daemon)")) then
        parity("package"; $item.name; $item.name; "not-applicable"; "native-replacement"; "macOS"; "This package implements the Linux kernel, desktop session, driver, boot, audio, network, or security platform that macOS already owns."; $item.source)
      elif (["jq","bat","btop","eza","fd","ffmpegthumbnailer","fzf","git","imagemagick","lazygit","mise-bin","nvim","ripgrep","starship","tldr","tmux","unzip","yt-dlp","zoxide"] | index($item.name) != null) then
        parity("package"; $item.name; $item.name; "implemented"; "exact"; "Brewfile"; "The portable tool or its current Homebrew package is installed by the default bundle."; $item.source)
      elif (["chromium","docker","kdenlive","libreoffice-fresh","localsend","moonlight-qt","obs-studio","obsidian","steam","xournalpp"] | index($item.name) != null) then
        parity("package"; $item.name; $item.name; "implemented"; "native-replacement"; "omacos package"; "A native macOS application or supported equivalent is available through the optional package catalog."; $item.source)
      else
        parity("package"; $item.name; $item.name; "limited"; "close-substitute"; "Homebrew or macOS built-in"; "This dependency is not installed one-to-one; OMacOS uses a built-in service, a differently named formula, or an optional user-selected tool."; $item.source)
      end;

  {
    schemaVersion: 1,
    reference: .reference,
    generatedFrom: "docs/quattro-inventory.json",
    grades: ["exact", "close-substitute", "native-replacement", "optional-unsafe", "impossible", "not-applicable"],
    statuses: ["implemented", "limited", "pending", "unavailable", "not-applicable"],
    items: {
      manual: [.manual[] | manual_parity],
      plugins: [.shellPlugins[] | plugin_parity],
      cliGroups: [.cliGroups[] | cli_parity],
      bindings: [.staticBindingDeclarations[] | binding_parity],
      dynamicBindingFamilies: [.dynamicBindingFamilies[] | dynamic_binding_parity],
      menuEntries: [.menuEntries[] | menu_parity],
      packages: [.defaultPackages[] | package_parity]
    }
  }
  | .summary = (
      [.items[][]]
      | {
          total: length,
          implemented: (map(select(.implementationStatus == "implemented")) | length),
          limited: (map(select(.implementationStatus == "limited")) | length),
          pending: (map(select(.implementationStatus == "pending")) | length),
          unavailable: (map(select(.implementationStatus == "unavailable")) | length),
          notApplicable: (map(select(.implementationStatus == "not-applicable")) | length)
        }
    )
' "$inventory_path" > "$temporary_path"

mv "$temporary_path" "$output_path"
trap - EXIT

{
  print '# Quattro parity ledger'
  print
  print 'Generated from the frozen Omarchy Quattro inventory. `implemented` means the outcome has an executable OMacOS or native macOS route; it does not claim that WindowServer behaves like Hyprland.'
  print
  print '## Summary'
  print
  print '| Total | Implemented | Limited | Pending | Unavailable | Not applicable |'
  print '| ---: | ---: | ---: | ---: | ---: | ---: |'
  jq -r '.summary | "| \(.total) | \(.implemented) | \(.limited) | \(.pending) | \(.unavailable) | \(.notApplicable) |"' "$output_path"
  print
  print '## Remaining portable work'
  print
  print '| Kind | Reference | Outcome | Route |'
  print '| --- | --- | --- | --- |'
  jq -r '[.items[][] | select(.implementationStatus == "pending")] | sort_by(.kind, .id)[] | "| \(.kind) | `\(.id)` | \(.title | gsub("\\|"; "\\\\|")) | `\(.route)` |"' "$output_path"
  print
  print '## Explicit platform limits'
  print
  print '| Kind | Reference | Outcome | Reason |'
  print '| --- | --- | --- | --- |'
  jq -r '[.items[][] | select(.implementationStatus == "unavailable")] | sort_by(.kind, .id)[] | "| \(.kind) | `\(.id)` | \(.title | gsub("\\|"; "\\\\|")) | \(.notes | gsub("\\|"; "\\\\|")) |"' "$output_path"
  print
  print 'The complete machine-readable ledger, including all implemented, limited, and not-applicable items, is in [`docs/quattro-parity.json`](quattro-parity.json).'
} > "$markdown_path"

print "Generated Quattro parity ledger: $output_path"
