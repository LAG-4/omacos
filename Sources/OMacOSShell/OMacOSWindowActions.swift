import AppKit
import ApplicationServices
import Foundation

enum OMacOSWindowActionError: LocalizedError {
    case accessibilityPermissionRequired
    case noFocusedWindow
    case windowSizeUnavailable
    case noSavedWidth
    case operationFailed(AXError)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required for this window action."
        case .noFocusedWindow:
            "No focused macOS window is available."
        case .windowSizeUnavailable:
            "The focused application does not expose a resizable window."
        case .noSavedWidth:
            "No saved window width exists. Use the save shortcut first."
        case let .operationFailed(error):
            "The macOS Accessibility operation failed with code \(error.rawValue)."
        }
    }
}

enum OMacOSWindowActions {
    static func saveFocusedWindowWidth(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> CGFloat {
        let width = try focusedWindowSize().width
        let path = savedWidthURL(environment: environment)
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try String(Double(width)).write(to: path, atomically: true, encoding: .utf8)
        return width
    }

    static func restoreFocusedWindowWidth(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> CGFloat {
        let path = savedWidthURL(environment: environment)
        guard let rawWidth = try? String(contentsOf: path, encoding: .utf8),
              let savedWidth = Double(rawWidth.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw OMacOSWindowActionError.noSavedWidth
        }
        let window = try focusedWindow()
        var size = try focusedWindowSize(window: window)
        size.width = CGFloat(savedWidth)
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw OMacOSWindowActionError.windowSizeUnavailable
        }
        let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        guard result == .success else { throw OMacOSWindowActionError.operationFailed(result) }
        return size.width
    }

    static func closeAllApplicationWindows() throws -> Int {
        try requireAccessibilityPermission()
        var closedCount = 0
        for application in NSWorkspace.shared.runningApplications
        where application.activationPolicy == .regular && application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                applicationElement,
                kAXWindowsAttribute as CFString,
                &windowsValue
            ) == .success,
                let windows = windowsValue as? [AXUIElement] else {
                continue
            }
            for window in windows {
                var closeButtonValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(
                    window,
                    kAXCloseButtonAttribute as CFString,
                    &closeButtonValue
                ) == .success,
                    let closeButtonValue else {
                    continue
                }
                let closeButton = unsafeDowncast(closeButtonValue, to: AXUIElement.self)
                if AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == .success {
                    closedCount += 1
                }
            }
        }
        return closedCount
    }

    private static func focusedWindowSize(window: AXUIElement? = nil) throws -> CGSize {
        let targetWindow = try window ?? focusedWindow()
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            targetWindow,
            kAXSizeAttribute as CFString,
            &sizeValue
        )
        guard result == .success, let sizeValue else {
            throw OMacOSWindowActionError.windowSizeUnavailable
        }
        let axValue = unsafeDowncast(sizeValue, to: AXValue.self)
        var size = CGSize.zero
        guard AXValueGetType(axValue) == .cgSize, AXValueGetValue(axValue, .cgSize, &size) else {
            throw OMacOSWindowActionError.windowSizeUnavailable
        }
        return size
    }

    private static func focusedWindow() throws -> AXUIElement {
        try requireAccessibilityPermission()
        let systemWideElement = AXUIElementCreateSystemWide()
        var applicationValue: CFTypeRef?
        let applicationResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &applicationValue
        )
        guard applicationResult == .success, let applicationValue else {
            throw OMacOSWindowActionError.noFocusedWindow
        }
        let applicationElement = unsafeDowncast(applicationValue, to: AXUIElement.self)
        var windowValue: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )
        guard windowResult == .success, let windowValue else {
            throw OMacOSWindowActionError.noFocusedWindow
        }
        return unsafeDowncast(windowValue, to: AXUIElement.self)
    }

    private static func requireAccessibilityPermission() throws {
        guard AXIsProcessTrusted() else {
            throw OMacOSWindowActionError.accessibilityPermissionRequired
        }
    }

    private static func savedWidthURL(environment: [String: String]) -> URL {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/window-width")
    }
}
