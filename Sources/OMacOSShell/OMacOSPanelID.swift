import Foundation

/// Stable panel identifiers used by the CLI, keybindings, bar, and shell IPC.
enum OMacOSPanelID: String, CaseIterable, Identifiable {
    case menu
    case keybindings
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
