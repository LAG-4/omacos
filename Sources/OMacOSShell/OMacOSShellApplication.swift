import AppKit
import SwiftUI

@MainActor
final class OMacOSBarWindowCoordinator {
    private let barState: OMacOSBarState
    private let togglePanel: (OMacOSPanelID) -> Void
    private var barPanels: [NSPanel] = []

    init(barState: OMacOSBarState, togglePanel: @escaping (OMacOSPanelID) -> Void) {
        self.barState = barState
        self.togglePanel = togglePanel
    }

    /// Rebuilds one non-activating bar panel for every connected display.
    func rebuildDisplayBars() {
        barPanels.forEach { $0.close() }
        barPanels = NSScreen.screens.map(makeBarPanel)
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
        panel.contentView = NSHostingView(rootView: OMacOSBarView(barState: barState, togglePanel: togglePanel))
        panel.orderFrontRegardless()
        return panel
    }
}

@MainActor
final class OMacOSPanelCoordinator: NSObject {
    private let theme: OMacOSTheme
    private let systemPanelState: OMacOSSystemPanelState
    private var activePanel: NSPanel?
    private var activePanelID: OMacOSPanelID?

    init(theme: OMacOSTheme, systemPanelState: OMacOSSystemPanelState) {
        self.theme = theme
        self.systemPanelState = systemPanelState
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
              userInfo[OMacOSShellMessage.actionKey] as? String == OMacOSShellMessage.togglePanelAction,
              let rawPanelID = userInfo[OMacOSShellMessage.panelKey] as? String,
              let panelID = OMacOSPanelID(rawValue: rawPanelID) else {
            return
        }
        togglePanel(panelID)
    }

    /// Opens or closes one native shell panel on the display containing the pointer.
    func togglePanel(_ panelID: OMacOSPanelID) {
        if let activePanel, activePanel.isVisible, activePanelID == panelID {
            dismissPanel()
            return
        }

        let targetScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let targetScreen else { return }

        activePanel?.close()
        let panelSize = size(for: panelID)
        let panelOrigin = NSPoint(
            x: targetScreen.frame.midX - panelSize.width / 2,
            y: targetScreen.frame.maxY - panelSize.height - 44
        )
        let panel = makePanel(panelID, size: panelSize)
        panel.setFrameOrigin(panelOrigin)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        activePanel = panel
        activePanelID = panelID
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
                rootView: OMacOSCommandMenuView(theme: theme) { [weak self] in
                    self?.dismissPanel()
                }
            )
        } else {
            panel.contentView = NSHostingView(
                rootView: OMacOSSystemPanelView(
                    panelID: panelID,
                    theme: theme,
                    state: systemPanelState
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
        case .menu: NSSize(width: 520, height: 390)
        case .keybindings: NSSize(width: 620, height: 620)
        case .clock: NSSize(width: 430, height: 520)
        default: NSSize(width: 430, height: 360)
        }
    }
}

@MainActor
final class OMacOSShellApplicationDelegate: NSObject, NSApplicationDelegate {
    private var barState: OMacOSBarState?
    private var systemPanelState: OMacOSSystemPanelState?
    private var barCoordinator: OMacOSBarWindowCoordinator?
    private var panelCoordinator: OMacOSPanelCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = OMacOSBarState()
        let panelState = OMacOSSystemPanelState()
        let panels = OMacOSPanelCoordinator(theme: state.theme, systemPanelState: panelState)
        let bars = OMacOSBarWindowCoordinator(barState: state) { [weak panels] panelID in
            panels?.togglePanel(panelID)
        }

        barState = state
        systemPanelState = panelState
        barCoordinator = bars
        panelCoordinator = panels

        state.startStatusUpdates()
        panelState.startStatusUpdates()
        bars.rebuildDisplayBars()
        if let previewPanelID = OMacOSShellMain.previewPanelID(from: CommandLine.arguments) {
            panels.togglePanel(previewPanelID)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildBarsAfterDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func rebuildBarsAfterDisplayChange() {
        barCoordinator?.rebuildDisplayBars()
    }
}

@main
enum OMacOSShellMain {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
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
        if arguments.contains("--toggle-menu") {
            return .menu
        }

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
