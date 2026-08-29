import Foundation

/// Stable panel identifiers used by the CLI, keybindings, bar, and shell IPC.
enum OMacOSPanelID: String, CaseIterable, Identifiable {
    case menu
    case keybindings
    case clipboard
    case emojis
    case capture
    case reminders
    case themes
    case wallpapers
    case defaults
    case agents
    case weather
    case media
    case dictation
    case notifications
    case speedtest
    case diskSpeedtest = "disk-speedtest"
    case wifiQR = "wifi-qr"
    case tailscale
    case dropbox
    case packages
    case plugins
    case devGallery = "dev-gallery"
    case osd
    case noticeDateTime = "notice-datetime"
    case noticeBattery = "notice-battery"
    case noticeWeather = "notice-weather"
    case system
    case audio
    case bluetooth
    case network
    case display
    case clock
    case power
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menu: "OMacOS"
        case .keybindings: "Keybindings"
        case .clipboard: "Clipboard"
        case .emojis: "Emoji"
        case .capture: "Capture"
        case .reminders: "Reminders"
        case .themes: "Themes"
        case .wallpapers: "Background"
        case .defaults: "Defaults"
        case .agents: "Agents"
        case .weather: "Weather"
        case .media: "Now Playing"
        case .dictation: "Dictation"
        case .notifications: "Notifications"
        case .speedtest: "Network Speed Test"
        case .diskSpeedtest: "Disk Speed Test"
        case .wifiQR: "Share Wi-Fi"
        case .tailscale: "Tailscale"
        case .dropbox: "Dropbox"
        case .packages: "Optional Apps"
        case .plugins: "Quattro Plugins"
        case .devGallery: "Developer Gallery"
        case .osd: "On-screen Display"
        case .noticeDateTime: "Date & Time"
        case .noticeBattery: "Battery"
        case .noticeWeather: "Weather"
        case .system: "System"
        case .audio: "Audio"
        case .bluetooth: "Bluetooth"
        case .network: "Network"
        case .display: "Display"
        case .clock: "Calendar"
        case .power: "Power"
        case .activity: "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .menu: "command"
        case .keybindings: "keyboard"
        case .clipboard: "clipboard"
        case .emojis: "face.smiling"
        case .capture: "camera.viewfinder"
        case .reminders: "bell"
        case .themes: "paintpalette"
        case .wallpapers: "photo.on.rectangle"
        case .defaults: "star"
        case .agents: "brain.head.profile"
        case .weather, .noticeWeather: "cloud.sun"
        case .media: "play.circle"
        case .dictation: "waveform.and.mic"
        case .notifications: "bell.badge"
        case .speedtest: "gauge.with.dots.needle.67percent"
        case .diskSpeedtest: "internaldrive"
        case .wifiQR: "qrcode"
        case .tailscale: "network.badge.shield.half.filled"
        case .dropbox: "shippingbox"
        case .packages: "shippingbox.and.arrow.backward"
        case .plugins: "puzzlepiece.extension"
        case .devGallery: "paintbrush.pointed"
        case .osd: "speaker.wave.2.circle"
        case .noticeDateTime: "clock"
        case .noticeBattery: "battery.75percent"
        case .system: "power"
        case .audio: "speaker.wave.2"
        case .bluetooth: "bolt.horizontal.circle"
        case .network: "wifi"
        case .display: "display"
        case .clock: "calendar"
        case .power: "battery.75percent"
        case .activity: "waveform.path.ecg"
        }
    }
}
