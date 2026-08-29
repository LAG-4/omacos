import AppKit
import Combine
import Foundation

@MainActor
final class OMacOSBarState: NSObject, ObservableObject {
    @Published private(set) var activeWorkspace = "1"
    @Published private(set) var frontmostApplication = "Finder"
    @Published private(set) var clockText = ""
    @Published private(set) var batteryText = ""

    let visibleWorkspaces = (1...9).map(String.init)
    let theme: OMacOSTheme

    private var refreshTimer: Timer?
    private let clockFormatter: DateFormatter

    override init() {
        theme = OMacOSTheme.loadCurrentTheme()
        clockFormatter = DateFormatter()
        clockFormatter.dateFormat = "EEE d MMM  HH:mm"
        super.init()
    }

    /// Starts polling the small set of system values displayed by the native bar.
    func startStatusUpdates() {
        refreshStatusValues()
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshStatusValues),
            userInfo: nil,
            repeats: true
        )
    }

    /// Switches the active workspace through the selected window-manager adapter.
    func focusWorkspace(_ workspace: String) {
        _ = OMacOSCommandRunner.run(
            executable: Self.omacosExecutable,
            arguments: ["wm", "workspace-focus", workspace]
        )
        activeWorkspace = workspace
    }

    @objc private func refreshStatusValues() {
        clockText = clockFormatter.string(from: Date())
        frontmostApplication = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Desktop"

        let workspaceResult = OMacOSCommandRunner.run(
            executable: Self.omacosExecutable,
            arguments: ["wm", "workspace-current"]
        )
        if workspaceResult.exitCode == 0, !workspaceResult.output.isEmpty {
            activeWorkspace = workspaceResult.output
        }

        let batteryResult = OMacOSCommandRunner.run(
            executable: "/usr/bin/pmset",
            arguments: ["-g", "batt"]
        )
        batteryText = Self.extractBatteryPercentage(from: batteryResult.output)
    }

    /// Extracts the first battery percentage from `pmset -g batt` output.
    nonisolated static func extractBatteryPercentage(from output: String) -> String {
        guard let match = output.range(of: #"\d+%"#, options: .regularExpression) else {
            return ""
        }
        return String(output[match])
    }

    /// Resolves the installed CLI while keeping `swift run omacos-shell` useful in development.
    nonisolated private static var omacosExecutable: String {
        let installed = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/omacos").path
        if FileManager.default.isExecutableFile(atPath: installed) {
            return installed
        }

        return FileManager.default.currentDirectoryPath + "/bin/omacos"
    }
}
