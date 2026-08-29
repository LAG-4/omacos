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
