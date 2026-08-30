import Foundation

enum OMacOSShellMessage {
    static let notificationName = Notification.Name("dev.omacos.shell.command")
    static let actionKey = "action"
    static let panelKey = "panel"
    static let valueKey = "value"
    static let togglePanelAction = "toggle-panel"
    static let toggleMenuAction = "toggle-menu"
    static let setBarHiddenAction = "set-bar-hidden"
    static let setBarPositionAction = "set-bar-position"
    static let setBarTransparencyAction = "set-bar-transparency"
    static let clearClipboardAction = "clear-clipboard"
    static let toggleDictationAction = "toggle-dictation"
    static let webcamOverlayAction = "webcam-overlay"
    static let pointerGestureAction = "pointer-gesture"
    static let windowGroupAction = "window-group"
    static let workspaceChangedAction = "workspace-changed"

    /// Posts one property-list-safe command to the already-running native shell.
    static func postTogglePanel(_ panelID: OMacOSPanelID) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [
                actionKey: togglePanelAction,
                panelKey: panelID.rawValue
            ],
            deliverImmediately: true
        )
    }

    static func postToggleMenu(_ menuID: String?) {
        var userInfo: [String: Any] = [actionKey: toggleMenuAction]
        if let menuID {
            userInfo[valueKey] = menuID
        }
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    static func postSetBarHidden(_ hidden: Bool) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [
                actionKey: setBarHiddenAction,
                valueKey: hidden
            ],
            deliverImmediately: true
        )
    }

    static func postClearClipboard() {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: clearClipboardAction],
            deliverImmediately: true
        )
    }

    static func postSetBarPosition(_ position: OMacOSBarPosition) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: setBarPositionAction, valueKey: position.rawValue],
            deliverImmediately: true
        )
    }

    static func postSetBarTransparency(_ transparent: Bool) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: setBarTransparencyAction, valueKey: transparent],
            deliverImmediately: true
        )
    }

    static func postDictationAction(_ action: String) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: toggleDictationAction, valueKey: action],
            deliverImmediately: true
        )
    }

    static func postWebcamOverlayAction(_ action: String) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: webcamOverlayAction, valueKey: action],
            deliverImmediately: true
        )
    }

    static func postPointerGestureAction(_ action: String) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: pointerGestureAction, valueKey: action],
            deliverImmediately: true
        )
    }

    static func postWindowGroupAction(_ action: String, value: String?) {
        var userInfo: [String: Any] = [actionKey: windowGroupAction, panelKey: action]
        if let value {
            userInfo[valueKey] = value
        }
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    /// Delivers an event-driven active workspace update from a window-manager adapter.
    static func postWorkspaceChanged(_ workspace: String) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: workspaceChangedAction, valueKey: workspace],
            deliverImmediately: true
        )
    }
}
