import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

struct OMacOSKeybinding: Codable, Identifiable {
    let key: String
    let modifiers: [String]
    let description: String
    let command: String

    var id: String { "\(modifiers.joined(separator: "+"))+\(key)+\(description)" }

    var displayChord: String {
        let modifierNames = modifiers.map { modifier in
            switch modifier {
            case "shift": "Shift"
            case "control": "Control"
            case "option": "Left Option"
            case "command": "Command"
            default: modifier.capitalized
            }
        }
        return (["Super"] + modifierNames + [Self.displayKeyName(key)]).joined(separator: " + ")
    }

    private static func displayKeyName(_ key: String) -> String {
        switch key {
        case "return_or_enter": "Return"
        case "spacebar": "Space"
        case "left_arrow": "Left"
        case "right_arrow": "Right"
        case "up_arrow": "Up"
        case "down_arrow": "Down"
        case "hyphen": "-"
        case "equal_sign": "="
        default: key.uppercased()
        }
    }
}

private struct OMacOSKeybindingDocument: Codable {
    let schemaVersion: Int
    let bindings: [OMacOSKeybinding]
}

@MainActor
final class OMacOSSystemPanelState: NSObject, ObservableObject {
    @Published private(set) var batteryPercentage = "—"
    @Published private(set) var batterySource = "Checking power source"
    @Published private(set) var volumePercentage = 0
    @Published private(set) var outputMuted = false
    @Published private(set) var networkName = "Checking network"
    @Published private(set) var bluetoothState = "Checking Bluetooth"
    @Published private(set) var systemLoad = "—"
    @Published private(set) var memorySummary = "—"
    @Published private(set) var uptimeSummary = "—"
    @Published private(set) var keybindings: [OMacOSKeybinding] = []
    @Published private(set) var availableThemes: [OMacOSTheme] = []
    @Published private(set) var lastRefresh = Date()
    @Published var panelSearchText = ""
    @Published private(set) var lastActionMessage = ""
    @Published private(set) var defaultTerminal = "ghostty"
    @Published private(set) var defaultBrowser = "system"
    @Published private(set) var defaultEditor = "nvim"

    private var refreshTimer: Timer?

    /// Begins lightweight polling for values shared by all native panels.
    func startStatusUpdates() {
        loadKeybindings()
        loadAvailableThemes()
        loadApplicationDefaults()
        refreshStatusValues()
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(refreshStatusValues),
            userInfo: nil,
            repeats: true
        )
    }

    func refreshNow() {
        refreshStatusValues()
    }

    func resetPanelSearch() {
        panelSearchText = ""
    }

    func setOutputVolume(_ volume: Int) {
        let boundedVolume = min(max(volume, 0), 100)
        _ = OMacOSCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "set volume output volume \(boundedVolume)"]
        )
        refreshStatusValues()
    }

    func toggleOutputMute() {
        let nextValue = outputMuted ? "false" : "true"
        _ = OMacOSCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "set volume output muted \(nextValue)"]
        )
        refreshStatusValues()
    }

    func openSystemSettings(_ pane: String? = nil) {
        if let pane {
            _ = OMacOSCommandRunner.run(executable: "/usr/bin/open", arguments: [pane])
        } else {
            _ = OMacOSCommandRunner.run(executable: "/usr/bin/open", arguments: ["-a", "System Settings"])
        }
    }

    func openApplication(_ application: String) {
        _ = OMacOSCommandRunner.run(executable: "/usr/bin/open", arguments: ["-a", application])
    }

    func applyTheme(_ theme: OMacOSTheme) {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let installedCLI = homeDirectory + "/.local/bin/omacos"
        let localRenderer = FileManager.default.currentDirectoryPath + "/scripts/render-theme.zsh"

        let result: OMacOSCommandResult
        if FileManager.default.isExecutableFile(atPath: installedCLI) {
            result = OMacOSCommandRunner.run(
                executable: "/usr/bin/env",
                arguments: [installedCLI, "theme", "apply", theme.slug]
            )
        } else {
            result = OMacOSCommandRunner.run(
                executable: "/usr/bin/env",
                arguments: [localRenderer, theme.slug]
            )
        }

        if result.exitCode == 0 {
            lastActionMessage = "Applied \(theme.name). Restart the shell to refresh every surface."
        } else {
            lastActionMessage = "Could not apply \(theme.name)."
        }
    }

    func chooseWallpaper() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose OMacOS Wallpaper"
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.png, .jpeg, .heic, .webP, .tiff]
        guard openPanel.runModal() == .OK, let wallpaperURL = openPanel.url else { return }

        var failedScreens: [String] = []
        for screen in NSScreen.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(wallpaperURL, for: screen, options: [:])
            } catch {
                failedScreens.append(screen.localizedName)
            }
        }

        if failedScreens.isEmpty {
            lastActionMessage = "Wallpaper applied to \(NSScreen.screens.count) display(s)."
        } else {
            lastActionMessage = "Wallpaper failed on: \(failedScreens.joined(separator: ", "))."
        }
    }

    func setApplicationDefault(category: String, value: String) {
        let script = projectScript(named: "defaults.zsh")
        let result = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [script, "set", category, value]
        )
        if result.exitCode == 0 {
            loadApplicationDefaults()
            lastActionMessage = "Set default \(category) to \(value)."
        } else {
            lastActionMessage = "Could not set default \(category)."
        }
    }

    func lockMac() {
        let lockTool = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        _ = OMacOSCommandRunner.run(executable: lockTool, arguments: ["-suspend"])
    }

    func sleepMac() {
        _ = OMacOSCommandRunner.run(executable: "/usr/bin/pmset", arguments: ["sleepnow"])
    }

    @objc private func refreshStatusValues() {
        refreshBatteryStatus()
        refreshAudioStatus()
        refreshNetworkStatus()
        refreshBluetoothStatus()
        refreshActivityStatus()
        lastRefresh = Date()
    }

    private func refreshBatteryStatus() {
        let result = OMacOSCommandRunner.run(executable: "/usr/bin/pmset", arguments: ["-g", "batt"])
        batteryPercentage = Self.firstMatch(in: result.output, pattern: #"\d+%"#) ?? "—"
        if result.output.localizedCaseInsensitiveContains("AC Power") {
            batterySource = "Power adapter"
        } else if result.output.localizedCaseInsensitiveContains("Battery Power") {
            batterySource = "Battery"
        } else {
            batterySource = "Power source unavailable"
        }
    }

    private func refreshAudioStatus() {
        let result = OMacOSCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "get volume settings"]
        )
        if let volume = Self.firstMatch(in: result.output, pattern: #"output volume:(\d+)"#, captureGroup: 1),
           let parsedVolume = Int(volume) {
            volumePercentage = parsedVolume
        }
        outputMuted = result.output.localizedCaseInsensitiveContains("output muted:true")
    }

    private func refreshNetworkStatus() {
        let hardwarePorts = OMacOSCommandRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: ["-listallhardwareports"]
        )
        let wifiDevice = Self.wifiDevice(from: hardwarePorts.output) ?? "en0"
        let network = OMacOSCommandRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: ["-getairportnetwork", wifiDevice]
        )
        if let separator = network.output.firstIndex(of: ":") {
            let candidate = network.output[network.output.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            networkName = candidate.isEmpty ? "Wi-Fi disconnected" : candidate
        } else if network.output.localizedCaseInsensitiveContains("not associated") {
            networkName = "Wi-Fi disconnected"
        } else {
            networkName = "Network status unavailable"
        }
    }

    private func refreshBluetoothStatus() {
        let result = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: ["blueutil", "--power"]
        )
        if result.exitCode == 0 {
            bluetoothState = result.output == "1" ? "Bluetooth on" : "Bluetooth off"
        } else {
            bluetoothState = "Open macOS Bluetooth settings"
        }
    }

    private func refreshActivityStatus() {
        let load = OMacOSCommandRunner.run(executable: "/usr/sbin/sysctl", arguments: ["-n", "vm.loadavg"])
        systemLoad = load.output.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")

        let memoryGiB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        memorySummary = String(format: "%.0f GB physical memory", memoryGiB)

        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let days = hours / 24
        uptimeSummary = days > 0 ? "\(days)d \(hours % 24)h uptime" : "\(hours)h uptime"
    }

    private func loadKeybindings() {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let candidateURLs = [
            URL(fileURLWithPath: homeDirectory).appendingPathComponent(".local/share/omacos/current/config/keybindings.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("config/keybindings.json")
        ]

        for url in candidateURLs where FileManager.default.fileExists(atPath: url.path) {
            guard let data = try? Data(contentsOf: url),
                  let document = try? JSONDecoder().decode(OMacOSKeybindingDocument.self, from: data),
                  document.schemaVersion == 1 else {
                continue
            }
            keybindings = document.bindings
            return
        }
    }

    private func loadAvailableThemes() {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let candidateDirectories = [
            URL(fileURLWithPath: homeDirectory).appendingPathComponent(".local/share/omacos/current/themes"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("themes")
        ]

        for directory in candidateDirectories {
            guard let themeURLs = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }
            let decodedThemes = themeURLs
                .filter { $0.pathExtension == "json" }
                .compactMap { try? OMacOSTheme.decodeTheme(at: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if !decodedThemes.isEmpty {
                availableThemes = decodedThemes
                return
            }
        }
    }

    private func loadApplicationDefaults() {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let defaultsURL = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".config/omacos/defaults.json")
        guard let data = try? Data(contentsOf: defaultsURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        defaultTerminal = object["terminal"] as? String ?? defaultTerminal
        defaultBrowser = object["browser"] as? String ?? defaultBrowser
        defaultEditor = object["editor"] as? String ?? defaultEditor
    }

    private func projectScript(named scriptName: String) -> String {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let installedScript = homeDirectory + "/.local/share/omacos/current/scripts/\(scriptName)"
        if FileManager.default.isExecutableFile(atPath: installedScript) {
            return installedScript
        }
        return FileManager.default.currentDirectoryPath + "/scripts/\(scriptName)"
    }

    nonisolated static func firstMatch(in input: String, pattern: String, captureGroup: Int = 0) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              captureGroup < match.numberOfRanges,
              let range = Range(match.range(at: captureGroup), in: input) else {
            return nil
        }
        return String(input[range])
    }

    nonisolated static func wifiDevice(from networkSetupOutput: String) -> String? {
        let blocks = networkSetupOutput.components(separatedBy: "\n\n")
        for block in blocks where block.localizedCaseInsensitiveContains("Hardware Port: Wi-Fi") {
            if let device = firstMatch(in: block, pattern: #"Device:\s*(\S+)"#, captureGroup: 1) {
                return device
            }
        }
        return nil
    }
}
