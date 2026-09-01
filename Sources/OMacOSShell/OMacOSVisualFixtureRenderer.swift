import AppKit
import SwiftUI

/// Renders deterministic shell fixtures without launching bars, services, or global event monitors.
@MainActor
enum OMacOSVisualFixtureRenderer {
    static func renderAll(to outputDirectory: URL) throws {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let theme = OMacOSTheme.loadCurrentTheme()
        let barState = OMacOSBarState(visualFixture: true)
        let systemState = OMacOSSystemPanelState()
        let agentStore = OMacOSAgentUsageStore()
        let dictationController = OMacOSDictationController()

        try render(
            OMacOSBarView(
                barState: barState,
                systemState: systemState,
                agentStore: agentStore,
                dictationController: dictationController,
                configuration: OMacOSBarConfiguration(position: .top, transparent: false),
                togglePanel: { _ in }
            ),
            size: NSSize(width: 1440, height: OMacOSBarGeometry.horizontalBarHeight),
            to: outputDirectory.appendingPathComponent("bar-horizontal.png")
        )

        try render(
            OMacOSBarView(
                barState: barState,
                systemState: systemState,
                agentStore: agentStore,
                dictationController: dictationController,
                configuration: OMacOSBarConfiguration(position: .left, transparent: false),
                togglePanel: { _ in }
            ),
            size: NSSize(width: OMacOSBarGeometry.verticalBarWidth, height: 900),
            to: outputDirectory.appendingPathComponent("bar-vertical.png")
        )

        try render(
            OMacOSCommandMenuView(theme: theme, dismissMenu: {}),
            size: NSSize(width: 1440, height: 900),
            to: outputDirectory.appendingPathComponent("command-menu.png")
        )

        let notificationStore = OMacOSNotificationStore()
        try render(
            OMacOSSystemPanelView(
                panelID: .system,
                theme: theme,
                state: systemState,
                clipboardStore: OMacOSClipboardStore(),
                reminderStore: OMacOSReminderStore(notificationStore: notificationStore),
                agentStore: agentStore,
                dictationController: dictationController,
                notificationStore: notificationStore,
                packageStore: OMacOSPackageStore(),
                pluginStore: OMacOSPluginCatalogStore(),
                dismissPanel: {}
            ),
            size: NSSize(width: 430, height: 430),
            to: outputDirectory.appendingPathComponent("system-panel.png")
        )
    }

    private static func render<Content: View>(
        _ content: Content,
        size: NSSize,
        to destination: URL
    ) throws {
        let hostingView = NSHostingView(
            rootView: content
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.display()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw OMacOSVisualFixtureError.unableToAllocateBitmap(destination.path)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw OMacOSVisualFixtureError.unableToEncodePNG(destination.path)
        }
        try pngData.write(to: destination, options: .atomic)
    }
}

enum OMacOSVisualFixtureError: LocalizedError {
    case unableToAllocateBitmap(String)
    case unableToEncodePNG(String)

    var errorDescription: String? {
        switch self {
        case let .unableToAllocateBitmap(path):
            "Unable to allocate a visual-fixture bitmap for \(path)"
        case let .unableToEncodePNG(path):
            "Unable to encode the visual fixture as PNG at \(path)"
        }
    }
}
