import AppKit
import Darwin
import Foundation

struct OMacOSDisplayReport: Codable {
    let name: String
    let width: Int
    let height: Int
    let visibleWidth: Int
    let visibleHeight: Int
    let scale: Double
    let maximumFramesPerSecond: Int
    let hasSafeAreaInsets: Bool
    let isMain: Bool
}

struct OMacOSHardwareReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let macOSVersion: String
    let macOSBuild: String
    let architecture: String
    let model: String
    let memoryBytes: UInt64
    let displayCount: Int
    let displays: [OMacOSDisplayReport]
    let permissions: OMacOSPermissionStatus

    @MainActor
    static func current() -> OMacOSHardwareReport {
        let displays = NSScreen.screens.map { screen in
            OMacOSDisplayReport(
                name: screen.localizedName,
                width: Int(screen.frame.width),
                height: Int(screen.frame.height),
                visibleWidth: Int(screen.visibleFrame.width),
                visibleHeight: Int(screen.visibleFrame.height),
                scale: Double(screen.backingScaleFactor),
                maximumFramesPerSecond: screen.maximumFramesPerSecond,
                hasSafeAreaInsets: screen.safeAreaInsets.top > 0
                    || screen.safeAreaInsets.left > 0
                    || screen.safeAreaInsets.bottom > 0
                    || screen.safeAreaInsets.right > 0,
                isMain: screen == NSScreen.main
            )
        }
        return OMacOSHardwareReport(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            macOSBuild: sysctlString("kern.osversion"),
            architecture: sysctlString("hw.machine"),
            model: sysctlString("hw.model"),
            memoryBytes: ProcessInfo.processInfo.physicalMemory,
            displayCount: displays.count,
            displays: displays,
            permissions: .current()
        )
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return "unknown" }
        let utf8 = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8, as: UTF8.self)
    }
}
