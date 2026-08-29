#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
omacos_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
open_command=${OMACOS_OPEN_BINARY:-/usr/bin/open}
osascript_command=${OMACOS_OSASCRIPT:-/usr/bin/osascript}
omacos_command=${OMACOS_CLI:-$omacos_home/.local/bin/omacos}
[[ -x $omacos_command ]] || omacos_command="$omacos_root/bin/omacos"

open_url() {
  "$open_command" "$1"
}

open_application() {
  "$open_command" -a "$1"
}

open_settings() {
  local pane=${1:-}
  if [[ -n $pane ]]; then
    "$open_command" "$pane"
  else
    open_application "System Settings"
  fi
}

open_panel() {
  "$omacos_command" shell toggle-panel "$1"
}

confirm_system_action() {
  local verb=$1
  local apple_event=$2
  "$osascript_command" -e "display dialog \"$verb this Mac now?\" buttons {\"Cancel\", \"$verb\"} default button \"$verb\" cancel button \"Cancel\" with icon caution" \
    -e "tell application \"System Events\" to $apple_event"
}

unsupported() {
  print "Not available on macOS: $1"
  return 2
}

run_menu_action() {
  local menu_id=$1
  case $menu_id in
    apps) open_application Launchpad || "$open_command" /Applications ;;
    about) open_url "https://github.com/LAG-4/omacos" ;;

    system.screensaver) "$omacos_command" toggle screensaver ;;
    system.lock) "$omacos_command" toggle lock ;;
    system.suspend) "$omacos_command" toggle sleep ;;
    system.hibernate) unsupported "macOS owns hibernation and safe-sleep policy" ;;
    system.logout) confirm_system_action "Log Out" "log out" ;;
    system.reboot) confirm_system_action "Restart" "restart" ;;
    system.shutdown) confirm_system_action "Shut Down" "shut down" ;;

    learn.keybindings) open_panel keybindings ;;
    learn.omarchy) open_url "https://omarchy.org/manual/" ;;
    learn.hyprland) open_url "https://github.com/LAG-4/omacos/blob/main/docs/support.md" ;;
    learn.arch) open_url "https://support.apple.com/guide/mac-help/welcome/mac" ;;
    learn.neovim) open_url "https://www.lazyvim.org/keymaps" ;;
    learn.bash) open_url "https://zsh.sourceforge.io/Doc/Release/" ;;
    learn.tmux-keybindings) open_url "https://github.com/tmux/tmux/wiki/Getting-Started" ;;
    learn.herdr-keybindings) open_url "https://github.com/LAG-4/herdr" ;;
    learn.community) open_url "https://github.com/LAG-4/omacos/discussions" ;;

    trigger.emoji) open_panel emojis ;;
    trigger.reminder|trigger.reminder.set|trigger.reminder.show|trigger.reminder.clear) open_panel reminders ;;
    trigger.capture.screenshot) "$omacos_command" capture screenshot ;;
    trigger.capture.text) "$omacos_command" capture text ;;
    trigger.capture.color) "$omacos_command" capture color ;;
    trigger.capture.screenrecord.no-audio) "$omacos_command" capture recording ;;
    trigger.capture.screenrecord.desktop-audio) "$omacos_command" capture recording --system-audio ;;
    trigger.capture.screenrecord.microphone) "$omacos_command" capture recording --all-audio ;;
    trigger.capture.screenrecord.stop) "$omacos_command" capture record-stop ;;
    trigger.capture.qr) "$omacos_command" capture qr ;;
    trigger.capture.screenrecord.webcam) "$omacos_command" capture recording --webcam ;;
    trigger.transcode) "$omacos_command" transcode choose ;;
    trigger.share|trigger.share.clipboard|trigger.share.file|trigger.share.folder|trigger.share.receive) "$omacos_command" share "${menu_id##*.}" ;;
    trigger.toggle.idle-lock) "$omacos_command" toggle toggle idle ;;
    trigger.toggle.notifications) "$omacos_command" toggle toggle notification-silencing ;;
    trigger.toggle.nightlight) "$omacos_command" toggle toggle night-light ;;
    trigger.toggle.top-bar) "$omacos_command" toggle toggle bar ;;
    trigger.toggle.workspace-layout) "$omacos_command" wm toggle-workspace-layout ;;
    trigger.toggle.window-gaps) "$omacos_command" wm gaps toggle ;;
    trigger.toggle.one-window-ratio) "$omacos_command" wm square-aspect-toggle ;;
    trigger.toggle.battery-percentage) open_settings "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension" ;;
    trigger.toggle.screensaver) open_settings "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" ;;
    trigger.toggle.crash-capture) open_application Console ;;
    trigger.hardware|trigger.hardware.laptop-display|trigger.hardware.mirror-display) open_panel display ;;
    trigger.hardware.touchpad|trigger.hardware.touchpad-haptics|trigger.hardware.touchpad-haptics.low|trigger.hardware.touchpad-haptics.mid|trigger.hardware.touchpad-haptics.high) open_settings "x-apple.systempreferences:com.apple.Trackpad-Settings.extension" ;;
    trigger.hardware.hybrid-gpu) unsupported "Apple Silicon does not expose switchable hybrid GPU modes" ;;
    trigger.hardware.touchscreen) unsupported "supported Macs do not expose a built-in touchscreen toggle" ;;
    trigger.tests.network-speedtest) open_panel speedtest ;;
    trigger.tests.disk-speedtest) open_panel disk-speedtest ;;

    style.theme) open_panel themes ;;
    style.background) open_panel wallpapers ;;
    style.unlock) print 'macOS owns the FileVault preboot unlock screen; a user-space rice cannot replace or theme it.' ;;
    style.font) open_application "Font Book" ;;
    style.bar|style.bar.position) "$omacos_command" bar status ;;
    style.bar.position.top) "$omacos_command" bar position top ;;
    style.bar.position.bottom) "$omacos_command" bar position bottom ;;
    style.bar.position.left) "$omacos_command" bar position left ;;
    style.bar.position.right) "$omacos_command" bar position right ;;
    style.bar.transparency) "$omacos_command" bar transparency toggle ;;
    style.hyprland) "$omacos_command" wm status ;;
    style.screensaver|style.screensaver.text|style.screensaver.image|style.screensaver.default) open_settings "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" ;;
    style.about|style.about.text|style.about.image|style.about.default) open_url "https://github.com/LAG-4/omacos" ;;

    setup.monitors) open_panel display ;;
    setup.keybindings) open_panel keybindings ;;
    setup.input) open_settings "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" ;;
    setup.network|setup.network.dns|setup.network.dns.dhcp|setup.network.dns.cloudflare|setup.network.dns.google|setup.network.dns.custom) open_panel network ;;
    setup.network.qr) open_panel wifi-qr ;;
    setup.default|setup.default.*) open_panel defaults ;;
    setup.plugin|setup.plugin.*) open_panel plugins ;;
    setup.security|setup.security.*) open_settings "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" ;;
    setup.config|setup.config.*) "$open_command" "$omacos_home/.config/omacos" ;;
    setup.direct-boot) open_settings "x-apple.systempreferences:com.apple.Startup-Disk-Settings.extension" ;;
    setup.reset) print "Use 'omacos uninstall' for a reversible reset. It shows the removal plan and asks for confirmation." ;;

    install|install.package|install.aur|install.ai|install.service|install.editor|install.style|install.gaming|install.browser|install.webapp|install.terminal|install.tui|install.windows|install.preinstalls|install.*) open_panel packages ;;
    remove|remove.package|remove.ai|remove.service|remove.development|remove.theme|remove.gaming|remove.browser|remove.webapp|remove.tui|remove.windows|remove.preinstalls|remove.security|remove.*) open_panel packages ;;

    update|update.omarchy) "$omacos_command" update check ;;
    update.channel) "$omacos_command" channel status ;;
    update.channel.stable) "$omacos_command" channel set stable ;;
    update.channel.edge) "$omacos_command" channel set edge ;;
    update.channel.rc) "$omacos_command" channel set rc ;;
    update.channel.dev) "$omacos_command" channel set dev ;;
    update.config|update.config.*|update.themes) "$omacos_command" update check ;;
    update.process|update.process.shell) "$omacos_command" shell restart ;;
    update.process.hyprsunset) open_settings "x-apple.systempreferences:com.apple.Displays-Settings.extension" ;;
    update.hardware|update.hardware.audio|update.hardware.wifi|update.hardware.bluetooth|update.hardware.trackpad) open_settings ;;
    update.firmware) open_settings "x-apple.systempreferences:com.apple.Software-Update-Settings.extension" ;;
    update.password|update.password.user) open_settings "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension" ;;
    update.password.drive) open_settings "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" ;;
    update.timezone|update.time) open_settings "x-apple.systempreferences:com.apple.Date-Time-Settings.extension" ;;

    *) unsupported "the Quattro entry '$menu_id' is Linux-specific or has no safe macOS adapter" ;;
  esac
}

case ${1:-} in
  run)
    [[ -n ${2:-} ]] || { print -u2 "Usage: omacos menu run ID"; exit 1; }
    run_menu_action "$2"
    ;;
  *) print -u2 "Usage: omacos menu run ID"; exit 1 ;;
esac
