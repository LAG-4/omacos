import Foundation

enum OMacOSShellMessage {
    static let notificationName = Notification.Name("dev.omacos.shell.command")
    static let actionKey = "action"
    static let panelKey = "panel"
    static let togglePanelAction = "toggle-panel"

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
}
