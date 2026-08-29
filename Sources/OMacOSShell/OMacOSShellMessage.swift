import Foundation

enum OMacOSShellMessage {
    static let notificationName = Notification.Name("dev.omacos.shell.command")
    static let actionKey = "action"
    static let panelKey = "panel"
    static let valueKey = "value"
    static let togglePanelAction = "toggle-panel"
    static let toggleMenuAction = "toggle-menu"
    static let setBarHiddenAction = "set-bar-hidden"
    static let toggleDictationAction = "toggle-dictation"

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

    static func postDictationAction(_ action: String) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [actionKey: toggleDictationAction, valueKey: action],
            deliverImmediately: true
        )
    }
}
