import AppKit
import SwiftUI

private let omacosToggleMenuNotification = Notification.Name("dev.omacos.shell.toggle-menu")

@MainActor
final class OMacOSBarWindowCoordinator {
    private let barState: OMacOSBarState
    private var barPanels: [NSPanel] = []

    init(barState: OMacOSBarState) {
        self.barState = barState
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
        panel.contentView = NSHostingView(rootView: OMacOSBarView(barState: barState))
        panel.orderFrontRegardless()
        return panel
    }
}

@MainActor
final class OMacOSCommandMenuCoordinator: NSObject {
    private let theme: OMacOSTheme
    private var menuPanel: NSPanel?

    init(theme: OMacOSTheme) {
        self.theme = theme
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receiveToggleCommandMenuNotification(_:)),
            name: omacosToggleMenuNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// Opens or closes the native command menu on the display containing the pointer.
    @objc private func receiveToggleCommandMenuNotification(_ notification: Notification) {
        toggleCommandMenu()
    }

    private func toggleCommandMenu() {
        if let menuPanel, menuPanel.isVisible {
            menuPanel.orderOut(nil)
            return
        }

        let targetScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let targetScreen else { return }

        let panelSize = NSSize(width: 520, height: 390)
        let panelOrigin = NSPoint(
            x: targetScreen.frame.midX - panelSize.width / 2,
            y: targetScreen.frame.maxY - panelSize.height - 44
        )
        let panel = menuPanel ?? makeCommandMenuPanel(size: panelSize)
        panel.setFrameOrigin(panelOrigin)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        menuPanel = panel
    }

    private func makeCommandMenuPanel(size: NSSize) -> NSPanel {
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
        panel.contentView = NSHostingView(
            rootView: OMacOSCommandMenuView(theme: theme) { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        return panel
    }
}

@MainActor
final class OMacOSShellApplicationDelegate: NSObject, NSApplicationDelegate {
    private var barState: OMacOSBarState?
    private var barCoordinator: OMacOSBarWindowCoordinator?
    private var commandMenuCoordinator: OMacOSCommandMenuCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = OMacOSBarState()
        let bars = OMacOSBarWindowCoordinator(barState: state)
        let commandMenu = OMacOSCommandMenuCoordinator(theme: state.theme)

        barState = state
        barCoordinator = bars
        commandMenuCoordinator = commandMenu

        state.startStatusUpdates()
        bars.rebuildDisplayBars()

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
        if CommandLine.arguments.contains("--toggle-menu") {
            DistributedNotificationCenter.default().postNotificationName(
                omacosToggleMenuNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            return
        }

        let application = NSApplication.shared
        let delegate = OMacOSShellApplicationDelegate()
        application.delegate = delegate
        application.run()
    }
}
