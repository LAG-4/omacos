import AppKit
import SwiftUI

@MainActor
final class OMacOSBarWindowCoordinator {
    private let barState: OMacOSBarState
    private let systemState: OMacOSSystemPanelState
    private let agentStore: OMacOSAgentUsageStore
    private let dictationController: OMacOSDictationController
    private let togglePanel: (OMacOSPanelID) -> Void
    private var barPanels: [NSPanel] = []
    private var barsHidden: Bool

    init(
        barState: OMacOSBarState,
        systemState: OMacOSSystemPanelState,
        agentStore: OMacOSAgentUsageStore,
        dictationController: OMacOSDictationController,
        togglePanel: @escaping (OMacOSPanelID) -> Void
    ) {
        self.barState = barState
        self.systemState = systemState
        self.agentStore = agentStore
        self.dictationController = dictationController
        self.togglePanel = togglePanel
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        barsHidden = FileManager.default.fileExists(
            atPath: homeDirectory + "/.local/state/omacos/toggles/bar-hidden.enabled"
        )
    }

    /// Rebuilds one non-activating bar panel for every connected display.
    func rebuildDisplayBars() {
        barPanels.forEach { $0.close() }
        barPanels = NSScreen.screens.map(makeBarPanel)
        if barsHidden {
            barPanels.forEach { $0.orderOut(nil) }
        }
    }

    func setBarsHidden(_ hidden: Bool) {
        barsHidden = hidden
        if hidden {
            barPanels.forEach { $0.orderOut(nil) }
        } else {
            barPanels.forEach { $0.orderFrontRegardless() }
        }
    }

    private func makeBarPanel(for screen: NSScreen) -> NSPanel {
        let barHeight: CGFloat = 34
        let panelFrame = NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - barHeight,
            width: screen.frame.width,
            height: barHeight
        )
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(
            rootView: OMacOSBarView(
                barState: barState,
                systemState: systemState,
                agentStore: agentStore,
                dictationController: dictationController,
                togglePanel: togglePanel
            )
        )
        panel.orderFrontRegardless()
        return panel
    }
}

@MainActor
final class OMacOSPanelCoordinator: NSObject {
    private let theme: OMacOSTheme
    private let systemPanelState: OMacOSSystemPanelState
    private let clipboardStore: OMacOSClipboardStore
    private let reminderStore: OMacOSReminderStore
    private let agentStore: OMacOSAgentUsageStore
    private let dictationController: OMacOSDictationController
    private let notificationStore: OMacOSNotificationStore
    private let packageStore: OMacOSPackageStore
    private let pluginStore: OMacOSPluginCatalogStore
    private var activePanel: NSPanel?
    private var activePanelID: OMacOSPanelID?
    private var requestedMenuID: String?

    init(
        theme: OMacOSTheme,
        systemPanelState: OMacOSSystemPanelState,
        clipboardStore: OMacOSClipboardStore,
        reminderStore: OMacOSReminderStore,
        agentStore: OMacOSAgentUsageStore,
        dictationController: OMacOSDictationController,
        notificationStore: OMacOSNotificationStore,
        packageStore: OMacOSPackageStore,
        pluginStore: OMacOSPluginCatalogStore
    ) {
        self.theme = theme
        self.systemPanelState = systemPanelState
        self.clipboardStore = clipboardStore
        self.reminderStore = reminderStore
        self.agentStore = agentStore
        self.dictationController = dictationController
        self.notificationStore = notificationStore
        self.packageStore = packageStore
        self.pluginStore = pluginStore
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receiveShellCommand(_:)),
            name: OMacOSShellMessage.notificationName,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// Routes property-list-safe commands sent by the CLI and generated keybindings.
    @objc private func receiveShellCommand(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo[OMacOSShellMessage.actionKey] as? String else {
            return
        }
        if action == OMacOSShellMessage.toggleMenuAction {
            requestedMenuID = userInfo[OMacOSShellMessage.valueKey] as? String
            togglePanel(.menu)
        } else if action == OMacOSShellMessage.togglePanelAction,
                  let rawPanelID = userInfo[OMacOSShellMessage.panelKey] as? String,
                  let panelID = OMacOSPanelID(rawValue: rawPanelID) {
            togglePanel(panelID)
        }
    }

    /// Opens or closes one native shell panel on the display containing the pointer.
    func togglePanel(_ panelID: OMacOSPanelID, targetScreen requestedScreen: NSScreen? = nil) {
        if let activePanel, activePanel.isVisible, activePanelID == panelID {
            dismissPanel()
            return
        }

        let targetScreen = requestedScreen
            ?? NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let targetScreen else { return }

        activePanel?.close()
        systemPanelState.resetPanelSearch()
        let panelSize = size(for: panelID)
        let panelOrigin = NSPoint(
            x: targetScreen.frame.midX - panelSize.width / 2,
            y: targetScreen.frame.maxY - panelSize.height - 44
        )
        let panel = makePanel(panelID, size: panelSize)
        panel.setFrameOrigin(panelOrigin)
        if panelID != .osd {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        activePanel = panel
        activePanelID = panelID
        if panelID == .osd {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.6))
                if self?.activePanelID == .osd {
                    self?.dismissPanel()
                }
            }
        }
    }

    private func makePanel(_ panelID: OMacOSPanelID, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        if panelID == .menu {
            panel.contentView = NSHostingView(
                rootView: OMacOSCommandMenuView(
                    theme: theme,
                    initialMenuID: requestedMenuID,
                    dismissMenu: { [weak self] in self?.dismissPanel() }
                )
            )
            requestedMenuID = nil
        } else {
            panel.contentView = NSHostingView(
                rootView: OMacOSSystemPanelView(
                    panelID: panelID,
                    theme: theme,
                    state: systemPanelState,
                    clipboardStore: clipboardStore,
                    reminderStore: reminderStore,
                    agentStore: agentStore,
                    dictationController: dictationController,
                    notificationStore: notificationStore,
                    packageStore: packageStore,
                    pluginStore: pluginStore
                ) { [weak self] in
                    self?.dismissPanel()
                }
            )
        }
        return panel
    }

    private func dismissPanel() {
        activePanel?.orderOut(nil)
        activePanelID = nil
    }

    private func size(for panelID: OMacOSPanelID) -> NSSize {
        switch panelID {
        case .menu: NSSize(width: 540, height: 620)
        case .keybindings, .clipboard, .emojis, .themes, .agents, .notifications, .packages, .plugins, .devGallery: NSSize(width: 620, height: 620)
        case .defaults: NSSize(width: 540, height: 540)
        case .clock: NSSize(width: 430, height: 520)
        case .system: NSSize(width: 430, height: 430)
        case .weather: NSSize(width: 430, height: 440)
        case .wifiQR: NSSize(width: 430, height: 440)
        case .noticeDateTime, .noticeBattery, .noticeWeather, .osd: NSSize(width: 430, height: 280)
        default: NSSize(width: 430, height: 360)
        }
    }
}

@MainActor
final class OMacOSShellApplicationDelegate: NSObject, NSApplicationDelegate {
    private var barState: OMacOSBarState?
    private var systemPanelState: OMacOSSystemPanelState?
    private var clipboardStore: OMacOSClipboardStore?
    private var reminderStore: OMacOSReminderStore?
    private var agentStore: OMacOSAgentUsageStore?
    private var dictationController: OMacOSDictationController?
    private var notificationStore: OMacOSNotificationStore?
    private var packageStore: OMacOSPackageStore?
    private var pluginStore: OMacOSPluginCatalogStore?
    private var barCoordinator: OMacOSBarWindowCoordinator?
    private var panelCoordinator: OMacOSPanelCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = OMacOSBarState()
        let panelState = OMacOSSystemPanelState()
        let clipboard = OMacOSClipboardStore()
        let notifications = OMacOSNotificationStore()
        let reminders = OMacOSReminderStore(notificationStore: notifications)
        let agents = OMacOSAgentUsageStore()
        let dictation = OMacOSDictationController()
        let packages = OMacOSPackageStore()
        let plugins = OMacOSPluginCatalogStore()
        let panels = OMacOSPanelCoordinator(
            theme: state.theme,
            systemPanelState: panelState,
            clipboardStore: clipboard,
            reminderStore: reminders,
            agentStore: agents,
            dictationController: dictation,
            notificationStore: notifications,
            packageStore: packages,
            pluginStore: plugins
        )
        let bars = OMacOSBarWindowCoordinator(
            barState: state,
            systemState: panelState,
            agentStore: agents,
            dictationController: dictation
        ) { [weak panels] panelID in
            panels?.togglePanel(panelID)
        }

        barState = state
        systemPanelState = panelState
        clipboardStore = clipboard
        reminderStore = reminders
        agentStore = agents
        dictationController = dictation
        notificationStore = notifications
        packageStore = packages
        pluginStore = plugins
        barCoordinator = bars
        panelCoordinator = panels

        state.startStatusUpdates()
        panelState.startStatusUpdates()
        clipboard.startCapture()
        reminders.startDelivery()
        agents.startMonitoring()
        bars.rebuildDisplayBars()
        if let previewPanelID = OMacOSShellMain.previewPanelID(from: CommandLine.arguments) {
            panels.togglePanel(previewPanelID, targetScreen: NSScreen.main)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildBarsAfterDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receiveShellCommand(_:)),
            name: OMacOSShellMessage.notificationName,
            object: nil
        )
    }

    @objc private func rebuildBarsAfterDisplayChange() {
        barCoordinator?.rebuildDisplayBars()
    }

    @objc private func receiveShellCommand(_ notification: Notification) {
        switch notification.userInfo?[OMacOSShellMessage.actionKey] as? String {
        case OMacOSShellMessage.setBarHiddenAction:
            if let hidden = notification.userInfo?[OMacOSShellMessage.valueKey] as? Bool {
                barCoordinator?.setBarsHidden(hidden)
            }
        case OMacOSShellMessage.toggleDictationAction:
            switch notification.userInfo?[OMacOSShellMessage.valueKey] as? String {
            case "start": dictationController?.start()
            case "stop": dictationController?.stopAndInsert()
            default: dictationController?.toggle()
            }
        default:
            break
        }
    }
}

@main
enum OMacOSShellMain {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        if let recognizeIndex = arguments.firstIndex(of: "--recognize-text"),
           arguments.indices.contains(recognizeIndex + 1) {
            do {
                let text = try OMacOSVisionRecognizer.recognizeText(
                    at: URL(fileURLWithPath: arguments[recognizeIndex + 1])
                )
                print(text)
                return
            } catch {
                FileHandle.standardError.write(Data("OMacOS text recognition failed: \(error)\n".utf8))
                Foundation.exit(1)
            }
        }

        if let recognizeIndex = arguments.firstIndex(of: "--recognize-qr"),
           arguments.indices.contains(recognizeIndex + 1) {
            do {
                let payload = try OMacOSVisionRecognizer.recognizeQRCode(
                    at: URL(fileURLWithPath: arguments[recognizeIndex + 1])
                )
                print(payload)
                return
            } catch {
                FileHandle.standardError.write(Data("OMacOS QR recognition failed: \(error)\n".utf8))
                Foundation.exit(1)
            }
        }

        if let widthIndex = arguments.firstIndex(of: "--window-width"),
           arguments.indices.contains(widthIndex + 1) {
            do {
                let width: CGFloat
                switch arguments[widthIndex + 1] {
                case "save": width = try OMacOSWindowActions.saveFocusedWindowWidth()
                case "restore": width = try OMacOSWindowActions.restoreFocusedWindowWidth()
                default:
                    FileHandle.standardError.write(Data("Window width action must be save or restore.\n".utf8))
                    Foundation.exit(2)
                }
                print(Int(width.rounded()))
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
        }

        if arguments.contains("--close-all-windows") {
            do {
                print(try OMacOSWindowActions.closeAllApplicationWindows())
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
        }

        if let reminderCommandIndex = arguments.firstIndex(of: "--reminder-add"),
           arguments.indices.contains(reminderCommandIndex + 2),
           let delay = TimeInterval(arguments[reminderCommandIndex + 1]) {
            let store = OMacOSReminderStore()
            guard let reminder = store.add(
                text: arguments[reminderCommandIndex + 2],
                dueAt: Date(timeIntervalSinceNow: delay)
            ) else {
                FileHandle.standardError.write(Data("Reminder text cannot be empty.\n".utf8))
                Foundation.exit(1)
            }
            print("\(reminder.id.uuidString)\t\(reminder.dueAt.ISO8601Format())\t\(reminder.text)")
            return
        }

        if let barHiddenIndex = arguments.firstIndex(of: "--set-bar-hidden"),
           arguments.indices.contains(barHiddenIndex + 1) {
            let hiddenValue = arguments[barHiddenIndex + 1]
            guard hiddenValue == "true" || hiddenValue == "false" else {
                FileHandle.standardError.write(Data("Bar visibility must be true or false.\n".utf8))
                Foundation.exit(2)
            }
            OMacOSShellMessage.postSetBarHidden(hiddenValue == "true")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
        }

        if let dictationIndex = arguments.firstIndex(of: "--dictation"),
           arguments.indices.contains(dictationIndex + 1) {
            let action = arguments[dictationIndex + 1]
            guard ["start", "stop", "toggle"].contains(action) else {
                FileHandle.standardError.write(Data("Dictation action must be start, stop, or toggle.\n".utf8))
                Foundation.exit(2)
            }
            OMacOSShellMessage.postDictationAction(action)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
        }

        if arguments.contains("--toggle-dictation") {
            OMacOSShellMessage.postDictationAction("toggle")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
        }

        if arguments.contains("--reminder-list") {
            let store = OMacOSReminderStore()
            for reminder in store.reminders {
                print("\(reminder.id.uuidString)\t\(reminder.dueAt.ISO8601Format())\t\(reminder.delivered ? "delivered" : "pending")\t\(reminder.text)")
            }
            return
        }

        if let notificationAddIndex = arguments.firstIndex(of: "--notification-add"),
           arguments.indices.contains(notificationAddIndex + 2) {
            let store = OMacOSNotificationStore()
            guard let record = store.add(
                title: arguments[notificationAddIndex + 1],
                body: arguments[notificationAddIndex + 2],
                source: "cli"
            ) else {
                Foundation.exit(1)
            }
            print("\(record.id.uuidString)\t\(record.createdAt.ISO8601Format())\t\(record.title)\t\(record.body)")
            return
        }

        if arguments.contains("--notification-list") {
            for record in OMacOSNotificationStore().records {
                print("\(record.id.uuidString)\t\(record.createdAt.ISO8601Format())\t\(record.title)\t\(record.body)")
            }
            return
        }

        if arguments.contains("--notification-clear") {
            OMacOSNotificationStore().clear()
            return
        }

        if arguments.contains("--notification-dismiss-one") {
            if let record = OMacOSNotificationStore().dismissMostRecent() {
                print("\(record.id.uuidString)\t\(record.title)\t\(record.body)")
            }
            return
        }

        if arguments.contains("--reminder-clear") {
            OMacOSReminderStore().clear()
            return
        }

        if arguments.contains("--reminder-deliver") {
            let notifications = OMacOSNotificationStore()
            OMacOSReminderStore(notificationStore: notifications).deliverDueReminders()
            return
        }

        if let toggleMenuIndex = arguments.firstIndex(of: "--toggle-menu") {
            let menuID = arguments.indices.contains(toggleMenuIndex + 1)
                ? arguments[toggleMenuIndex + 1]
                : nil
            OMacOSShellMessage.postToggleMenu(menuID)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
        }

        if let panelID = requestedPanelID(from: arguments) {
            OMacOSShellMessage.postTogglePanel(panelID)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
        }

        if arguments.contains("--toggle-panel") || arguments.contains("--toggle-menu") {
            FileHandle.standardError.write(Data("Unknown OMacOS shell panel.\n".utf8))
            Foundation.exit(2)
        }

        let application = NSApplication.shared
        let delegate = OMacOSShellApplicationDelegate()
        application.delegate = delegate
        application.run()
    }

    static func requestedPanelID(from arguments: [String]) -> OMacOSPanelID? {
        guard let toggleIndex = arguments.firstIndex(of: "--toggle-panel"),
              arguments.indices.contains(toggleIndex + 1) else {
            return nil
        }
        return OMacOSPanelID(rawValue: arguments[toggleIndex + 1])
    }

    static func previewPanelID(from arguments: [String]) -> OMacOSPanelID? {
        guard let previewIndex = arguments.firstIndex(of: "--preview-panel"),
              arguments.indices.contains(previewIndex + 1) else {
            return nil
        }
        return OMacOSPanelID(rawValue: arguments[previewIndex + 1])
    }
}
