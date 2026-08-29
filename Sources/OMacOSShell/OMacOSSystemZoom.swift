import ApplicationServices
import Foundation

enum OMacOSSystemZoomError: LocalizedError {
    case accessibilityPermissionRequired
    case eventCreationFailed
    case unknownAction(String)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required to invoke the macOS zoom shortcuts."
        case .eventCreationFailed:
            return "macOS could not create the accessibility zoom keyboard event."
        case let .unknownAction(action):
            return "Unknown system zoom action: \(action)"
        }
    }
}

enum OMacOSSystemZoom {
    static func perform(_ action: String) throws {
        guard ["in", "reset"].contains(action) else {
            throw OMacOSSystemZoomError.unknownAction(action)
        }
        guard AXIsProcessTrusted() else {
            throw OMacOSSystemZoomError.accessibilityPermissionRequired
        }

        switch action {
        case "in":
            try postKey(24)
        case "reset":
            for _ in 0..<32 {
                try postKey(27)
                Thread.sleep(forTimeInterval: 0.01)
            }
        default:
            break
        }
    }

    private static func postKey(_ virtualKey: CGKeyCode) throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            throw OMacOSSystemZoomError.eventCreationFailed
        }
        let flags: CGEventFlags = [.maskCommand, .maskAlternate]
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
