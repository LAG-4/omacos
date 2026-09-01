import AppKit
import Combine
import Foundation

@MainActor
final class OMacOSBarState: NSObject, ObservableObject {
    @Published private(set) var activeWorkspace = "1"
    @Published private(set) var frontmostApplication = "Finder"
    @Published private(set) var clockText = ""
    @Published private(set) var batteryText = ""

    let theme: OMacOSTheme

    /// Mirrors Quattro: workspaces 1–5 are stable; a focused higher workspace is appended.
    var visibleWorkspaces: [String] {
        var workspaces = (1...5).map(String.init)
        if let activeNumber = Int(activeWorkspace), (6...10).contains(activeNumber) {
            workspaces.append(activeWorkspace)
        }
        return workspaces
    }

    private var refreshTimer: Timer?
    private var workspaceMonitor: OMacOSWorkspaceMonitor?
    private let clockFormatter: DateFormatter

    override init() {
        theme = OMacOSTheme.loadCurrentTheme()
        clockFormatter = DateFormatter()
        clockFormatter.dateFormat = "EEEE HH:mm"
        super.init()
        workspaceMonitor = OMacOSWorkspaceMonitor { [weak self] workspace in
            self?.updateActiveWorkspace(workspace)
        }
    }

    /// Supplies stable values to the off-screen visual renderer without starting system polling.
    convenience init(visualFixture: Bool) {
        self.init()
        if visualFixture {
            activeWorkspace = "1"
            clockText = "Monday 19:14"
            batteryText = "97%"
        }
    }

    /// Starts polling the small set of system values displayed by the native bar.
    func startStatusUpdates() {
        refreshStatusValues()
        workspaceMonitor?.start()
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

    /// Applies a workspace change reported by the active window-manager adapter.
    func updateActiveWorkspace(_ workspace: String) {
        guard !workspace.isEmpty else { return }
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
