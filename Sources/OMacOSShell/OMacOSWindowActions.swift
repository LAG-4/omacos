import AppKit
import ApplicationServices
import Foundation

enum OMacOSWindowActionError: LocalizedError {
    case accessibilityPermissionRequired
    case noFocusedWindow
    case windowSizeUnavailable
    case noSavedWidth
    case noSavedFullWidthFrame
    case noSavedSquareFrame
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
        case .noSavedFullWidthFrame:
            "No saved window frame exists for restoring full width."
        case .noSavedSquareFrame:
            "No saved window frame exists for restoring the square-aspect toggle."
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
        let window = try focusedWindowElement()
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

    static func toggleFocusedWindowFullWidth(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> CGFloat {
        let window = try focusedWindowElement()
        let currentFrame = try windowFrame(window)
        let visibleFrame = visibleScreenFrame(containing: currentFrame)
        let savedFramePath = savedFullWidthFrameURL(environment: environment)
        let isFullWidth = abs(currentFrame.minX - visibleFrame.minX) < 2
            && abs(currentFrame.width - visibleFrame.width) < 2

        let targetFrame: CGRect
        if isFullWidth {
            guard let data = try? Data(contentsOf: savedFramePath),
                  let savedFrame = try? JSONDecoder().decode(SavedHorizontalFrame.self, from: data) else {
                throw OMacOSWindowActionError.noSavedFullWidthFrame
            }
            targetFrame = CGRect(
                x: savedFrame.x,
                y: currentFrame.minY,
                width: savedFrame.width,
                height: currentFrame.height
            )
        } else {
            try FileManager.default.createDirectory(
                at: savedFramePath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(
                SavedHorizontalFrame(x: currentFrame.minX, width: currentFrame.width)
            )
            try data.write(to: savedFramePath, options: .atomic)
            targetFrame = CGRect(
                x: visibleFrame.minX,
                y: currentFrame.minY,
                width: visibleFrame.width,
                height: currentFrame.height
            )
        }

        try setWindowFrame(targetFrame, window: window)
        return targetFrame.width
    }

    static func toggleFocusedWindowSquareAspect(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> CGSize {
        let window = try focusedWindowElement()
        let currentFrame = try windowFrame(window)
        let savedFramePath = savedSquareFrameURL(environment: environment)
        let isSquare = abs(currentFrame.width - currentFrame.height) < 2

        let targetFrame: CGRect
        if isSquare {
            guard let data = try? Data(contentsOf: savedFramePath),
                  let savedFrame = try? JSONDecoder().decode(SavedWindowFrame.self, from: data) else {
                throw OMacOSWindowActionError.noSavedSquareFrame
            }
            targetFrame = savedFrame.cgRect
        } else {
            try FileManager.default.createDirectory(
                at: savedFramePath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(SavedWindowFrame(currentFrame))
                .write(to: savedFramePath, options: .atomic)
            let side = min(currentFrame.width, currentFrame.height)
            targetFrame = CGRect(
                x: currentFrame.midX - side / 2,
                y: currentFrame.midY - side / 2,
                width: side,
                height: side
            )
        }

        try setWindowFrame(targetFrame, window: window)
        return targetFrame.size
    }

    static func toggleFocusedWindowPseudo(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> Bool {
        let window = try focusedWindowElement()
        let currentFrame = try windowFrame(window)
        let savedFramePath = savedPseudoFrameURL(environment: environment)
        var processIdentifier: pid_t = 0
        AXUIElementGetPid(window, &processIdentifier)

        if let data = try? Data(contentsOf: savedFramePath),
           let savedFrame = try? JSONDecoder().decode(SavedPseudoFrame.self, from: data),
           savedFrame.processIdentifier == processIdentifier {
            try setWindowFrame(savedFrame.frame.cgRect, window: window)
            try? FileManager.default.removeItem(at: savedFramePath)
            return false
        }

        try FileManager.default.createDirectory(
            at: savedFramePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let savedFrame = SavedPseudoFrame(
            processIdentifier: processIdentifier,
            frame: SavedWindowFrame(currentFrame)
        )
        try JSONEncoder().encode(savedFrame).write(to: savedFramePath, options: .atomic)
        let targetWidth = min(currentFrame.width, max(320, currentFrame.width * 0.72))
        let targetHeight = min(currentFrame.height, max(220, currentFrame.height * 0.72))
        let targetFrame = CGRect(
            x: currentFrame.midX - targetWidth / 2,
            y: currentFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        try setWindowFrame(targetFrame, window: window)
        return true
    }

    private static func focusedWindowSize(window: AXUIElement? = nil) throws -> CGSize {
        let targetWindow = try window ?? focusedWindowElement()
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

    static func windowFrame(_ window: AXUIElement) throws -> CGRect {
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )
        guard positionResult == .success, let positionValue else {
            throw OMacOSWindowActionError.windowSizeUnavailable
        }
        let positionAXValue = unsafeDowncast(positionValue, to: AXValue.self)
        var position = CGPoint.zero
        guard AXValueGetType(positionAXValue) == .cgPoint,
              AXValueGetValue(positionAXValue, .cgPoint, &position) else {
            throw OMacOSWindowActionError.windowSizeUnavailable
        }
        return CGRect(origin: position, size: try focusedWindowSize(window: window))
    }

    static func setWindowFrame(_ frame: CGRect, window: AXUIElement) throws {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw OMacOSWindowActionError.windowSizeUnavailable
        }
        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        guard positionResult == .success else {
            throw OMacOSWindowActionError.operationFailed(positionResult)
        }
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        guard sizeResult == .success else {
            throw OMacOSWindowActionError.operationFailed(sizeResult)
        }
    }

    private static func visibleScreenFrame(containing windowFrame: CGRect) -> CGRect {
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return windowFrame }
        let primaryMaximumY = primaryScreen.frame.maxY
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let matchingScreen = screens.first { screen in
            let quartzFrame = CGRect(
                x: screen.frame.minX,
                y: primaryMaximumY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return quartzFrame.contains(windowCenter)
        } ?? primaryScreen
        return matchingScreen.visibleFrame
    }

    static func focusedWindowElement() throws -> AXUIElement {
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

    static func visibleWindowElements() throws -> [AXUIElement] {
        try requireAccessibilityPermission()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .flatMap { application -> [AXUIElement] in
                let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
                var windowsValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(
                    applicationElement,
                    kAXWindowsAttribute as CFString,
                    &windowsValue
                ) == .success else {
                    return []
                }
                return windowsValue as? [AXUIElement] ?? []
            }
            .filter { (try? windowFrame($0).width) ?? 0 > 1 }
    }

    static func raiseWindow(_ window: AXUIElement) {
        var processIdentifier: pid_t = 0
        if AXUIElementGetPid(window, &processIdentifier) == .success {
            NSRunningApplication(processIdentifier: processIdentifier)?.activate(options: [])
        }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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

    private static func savedFullWidthFrameURL(environment: [String: String]) -> URL {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/window-full-width.json")
    }

    private static func savedSquareFrameURL(environment: [String: String]) -> URL {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/window-square-frame.json")
    }

    private static func savedPseudoFrameURL(environment: [String: String]) -> URL {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/window-pseudo-frame.json")
    }
}

private struct SavedHorizontalFrame: Codable {
    let x: CGFloat
    let width: CGFloat
}

private struct SavedWindowFrame: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(_ frame: CGRect) {
        x = frame.minX
        y = frame.minY
        width = frame.width
        height = frame.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct SavedPseudoFrame: Codable {
    let processIdentifier: pid_t
    let frame: SavedWindowFrame
}
