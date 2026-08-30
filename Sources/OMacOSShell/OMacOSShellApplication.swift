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
    private var configuration: OMacOSBarConfiguration

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
        configuration = OMacOSBarConfiguration.load(environment: environment)
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

    func setBarPosition(_ position: OMacOSBarPosition) {
        configuration.position = position
        rebuildDisplayBars()
    }

    func setBarTransparency(_ transparent: Bool) {
        configuration.transparent = transparent
        rebuildDisplayBars()
    }

    private func makeBarPanel(for screen: NSScreen) -> NSPanel {
        let panelFrame = OMacOSBarGeometry.localPanelFrame(
            screenSize: screen.frame.size,
            position: configuration.position
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
                configuration: configuration,
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
        } else if action == OMacOSShellMessage.clearClipboardAction {
            clipboardStore.clear()
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
        let barConfiguration = OMacOSBarConfiguration.load()
        let panelOrigin: NSPoint
        switch barConfiguration.position {
        case .top:
            panelOrigin = NSPoint(x: targetScreen.frame.midX - panelSize.width / 2, y: targetScreen.frame.maxY - panelSize.height - 44)
        case .bottom:
            panelOrigin = NSPoint(x: targetScreen.frame.midX - panelSize.width / 2, y: targetScreen.frame.minY + 44)
        case .left:
            panelOrigin = NSPoint(x: targetScreen.frame.minX + 58, y: targetScreen.frame.midY - panelSize.height / 2)
        case .right:
            panelOrigin = NSPoint(x: targetScreen.frame.maxX - panelSize.width - 58, y: targetScreen.frame.midY - panelSize.height / 2)
        }
        let panel = makePanel(panelID, size: panelSize)
        panel.setFrameOrigin(panelOrigin)
        if panelID != .osd {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        activePanel = panel
        activePanelID = panelID
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.focusInitialPanelControl(in: panel, panelID: panelID)
        }
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
        panel.autorecalculatesKeyViewLoop = true
        panel.initialFirstResponder = panel.contentView
        return panel
    }

    private func focusInitialPanelControl(in panel: NSPanel, panelID: OMacOSPanelID) {
        panel.contentView?.layoutSubtreeIfNeeded()
        switch panelID {
        case .menu, .keybindings, .clipboard, .emojis, .reminders, .themes:
            if let textField = firstTextField(in: panel.contentView) {
                panel.makeFirstResponder(textField)
            } else {
                panel.makeFirstResponder(panel.contentView)
            }
        default:
            panel.makeFirstResponder(panel.contentView)
        }
        panel.recalculateKeyViewLoop()
    }

    private func firstTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let textField = view as? NSTextField, textField.isEditable {
            return textField
        }
        for subview in view.subviews {
            if let textField = firstTextField(in: subview) {
                return textField
            }
        }
        return nil
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
    private var webcamOverlayController: OMacOSWebcamOverlayController?
    private var pointerGestureController: OMacOSPointerGestureController?
    private var windowGroupController: OMacOSWindowGroupController?

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
        let webcamOverlay = OMacOSWebcamOverlayController()
        let pointerGestures = OMacOSPointerGestureController()
        let windowGroups = OMacOSWindowGroupController()
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
        webcamOverlayController = webcamOverlay
        pointerGestureController = pointerGestures
        windowGroupController = windowGroups

        state.startStatusUpdates()
        panelState.startStatusUpdates()
        clipboard.startCapture()
        reminders.startDelivery()
        agents.startMonitoring()
        bars.rebuildDisplayBars()
        pointerGestures.start()
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
        case OMacOSShellMessage.setBarPositionAction:
            if let rawPosition = notification.userInfo?[OMacOSShellMessage.valueKey] as? String,
               let position = OMacOSBarPosition(rawValue: rawPosition) {
                barCoordinator?.setBarPosition(position)
            }
        case OMacOSShellMessage.setBarTransparencyAction:
            if let transparent = notification.userInfo?[OMacOSShellMessage.valueKey] as? Bool {
                barCoordinator?.setBarTransparency(transparent)
            }
        case OMacOSShellMessage.toggleDictationAction:
            switch notification.userInfo?[OMacOSShellMessage.valueKey] as? String {
            case "start": dictationController?.start()
            case "stop": dictationController?.stopAndInsert()
            default: dictationController?.toggle()
            }
        case OMacOSShellMessage.webcamOverlayAction:
            if let action = notification.userInfo?[OMacOSShellMessage.valueKey] as? String {
                webcamOverlayController?.perform(action)
            }
        case OMacOSShellMessage.pointerGestureAction:
            if let action = notification.userInfo?[OMacOSShellMessage.valueKey] as? String {
                pointerGestureController?.perform(action)
            }
        case OMacOSShellMessage.windowGroupAction:
            if let action = notification.userInfo?[OMacOSShellMessage.panelKey] as? String {
                windowGroupController?.perform(
                    action,
                    value: notification.userInfo?[OMacOSShellMessage.valueKey] as? String
                )
            }
        case OMacOSShellMessage.workspaceChangedAction:
            if let workspace = notification.userInfo?[OMacOSShellMessage.valueKey] as? String {
                barState?.updateActiveWorkspace(workspace)
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
        if arguments.contains("--permission-status") {
            do {
                let data = try JSONEncoder().encode(OMacOSPermissionStatus.current())
                print(String(decoding: data, as: UTF8.self))
                return
            } catch {
                FileHandle.standardError.write(Data("Unable to encode permission status: \(error)\n".utf8))
                Foundation.exit(1)
            }
        }

        if arguments.contains("--hardware-report") {
            do {
                let data = try JSONEncoder().encode(OMacOSHardwareReport.current())
                print(String(decoding: data, as: UTF8.self))
                return
            } catch {
                FileHandle.standardError.write(Data("Unable to encode hardware report: \(error)\n".utf8))
                Foundation.exit(1)
            }
        }

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

        if arguments.contains("--window-full-width") {
            do {
                print(Int(try OMacOSWindowActions.toggleFocusedWindowFullWidth().rounded()))
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
        }

        if arguments.contains("--window-square-aspect") {
            do {
                let size = try OMacOSWindowActions.toggleFocusedWindowSquareAspect()
                print("\(Int(size.width.rounded()))x\(Int(size.height.rounded()))")
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
        }

        if arguments.contains("--window-pseudo") {
            do {
                print(try OMacOSWindowActions.toggleFocusedWindowPseudo() ? "enabled" : "disabled")
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

        if arguments.contains("--clipboard-clear") {
            OMacOSShellMessage.postClearClipboard()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
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

        if arguments.contains("--bar-status") {
            do {
                let data = try JSONEncoder().encode(OMacOSBarConfiguration.load())
                print(String(decoding: data, as: UTF8.self))
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
        }

        if let barPositionIndex = arguments.firstIndex(of: "--bar-position"),
           arguments.indices.contains(barPositionIndex + 1) {
            let rawPosition = arguments[barPositionIndex + 1]
            guard let position = OMacOSBarPosition(rawValue: rawPosition) else {
                FileHandle.standardError.write(Data("Bar position must be top, bottom, left, or right.\n".utf8))
                Foundation.exit(2)
            }
            do {
                var configuration = OMacOSBarConfiguration.load()
                configuration.position = position
                try configuration.save()
                OMacOSShellMessage.postSetBarPosition(position)
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
        }

        if let transparencyIndex = arguments.firstIndex(of: "--bar-transparency"),
           arguments.indices.contains(transparencyIndex + 1) {
            let rawTransparency = arguments[transparencyIndex + 1]
            guard rawTransparency == "true" || rawTransparency == "false" else {
                FileHandle.standardError.write(Data("Bar transparency must be true or false.\n".utf8))
                Foundation.exit(2)
            }
            do {
                var configuration = OMacOSBarConfiguration.load()
                configuration.transparent = rawTransparency == "true"
                try configuration.save()
                OMacOSShellMessage.postSetBarTransparency(configuration.transparent)
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
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

        if let webcamIndex = arguments.firstIndex(of: "--webcam-overlay"),
           arguments.indices.contains(webcamIndex + 1) {
            let action = arguments[webcamIndex + 1]
            guard ["start", "stop", "smaller", "larger"].contains(action) else {
                FileHandle.standardError.write(Data("Webcam overlay action must be start, stop, smaller, or larger.\n".utf8))
                Foundation.exit(2)
            }
            OMacOSShellMessage.postWebcamOverlayAction(action)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            return
        }

        if let pointerIndex = arguments.firstIndex(of: "--pointer-gesture"),
           arguments.indices.contains(pointerIndex + 1) {
            let action = arguments[pointerIndex + 1]
            guard ["super-down", "super-up", "begin-move", "begin-resize", "end"].contains(action) else {
                FileHandle.standardError.write(Data("Unknown pointer gesture action.\n".utf8))
                Foundation.exit(2)
            }
            OMacOSShellMessage.postPointerGestureAction(action)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
            return
        }

        if let groupIndex = arguments.firstIndex(of: "--window-group"),
           arguments.indices.contains(groupIndex + 1) {
            let action = arguments[groupIndex + 1]
            guard ["toggle", "out", "join", "next", "previous", "index"].contains(action) else {
                FileHandle.standardError.write(Data("Unknown window group action.\n".utf8))
                Foundation.exit(2)
            }
            let value = arguments.indices.contains(groupIndex + 2) ? arguments[groupIndex + 2] : nil
            OMacOSShellMessage.postWindowGroupAction(action, value: value)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            return
        }

        if let workspaceIndex = arguments.firstIndex(of: "--workspace-changed"),
           arguments.indices.contains(workspaceIndex + 1) {
            OMacOSShellMessage.postWorkspaceChanged(arguments[workspaceIndex + 1])
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
            return
        }

        if let zoomIndex = arguments.firstIndex(of: "--system-zoom"),
           arguments.indices.contains(zoomIndex + 1) {
            do {
                try OMacOSSystemZoom.perform(arguments[zoomIndex + 1])
                return
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                Foundation.exit(1)
            }
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
            let actionURL = arguments.indices.contains(notificationAddIndex + 3)
                ? arguments[notificationAddIndex + 3]
                : nil
            guard let record = store.add(
                title: arguments[notificationAddIndex + 1],
                body: arguments[notificationAddIndex + 2],
                source: "cli",
                actionURL: actionURL
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

        if arguments.contains("--notification-action-url") {
            guard let actionURL = OMacOSNotificationStore().mostRecentActionURL() else {
                FileHandle.standardError.write(Data("The most recent OMacOS notification has no action URL.\n".utf8))
                Foundation.exit(1)
            }
            print(actionURL.absoluteString)
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
