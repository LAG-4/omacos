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

struct OMacOSWeatherForecast: Codable, Identifiable {
    let date: String
    let minimumC: Int
    let maximumC: Int
    let description: String

    var id: String { date }
}

struct OMacOSWeatherStatus: Codable {
    let schemaVersion: Int
    let location: String
    let region: String
    let temperatureC: Int
    let feelsLikeC: Int
    let description: String
    let humidity: Int
    let windKmph: Int
    let forecast: [OMacOSWeatherForecast]
}

struct OMacOSMediaStatus: Codable {
    let schemaVersion: Int
    let state: String
    let title: String
    let artist: String
    let application: String

    var isPlaying: Bool { state == "playing" }
    var hasTrack: Bool { !title.isEmpty }
}

struct OMacOSWiFiCredentials: Codable {
    let schemaVersion: Int
    let ssid: String
    let password: String
    let security: String
    let payload: String
}

struct OMacOSTailscaleMachine: Codable, Identifiable {
    let id: String
    let name: String
    let dnsName: String
    let ip: String
    let online: Bool
}

struct OMacOSTailscaleStatus: Codable {
    let schemaVersion: Int
    let installed: Bool
    let online: Bool
    let tailnet: String
    let machines: [OMacOSTailscaleMachine]
}

struct OMacOSDropboxStatus: Codable {
    let schemaVersion: Int
    let installed: Bool
    let running: Bool
    let path: String
    let storageKB: Int
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
    @Published private(set) var weatherStatus: OMacOSWeatherStatus?
    @Published private(set) var weatherMessage = "Select refresh to load the forecast."
    @Published private(set) var mediaStatus: OMacOSMediaStatus?
    @Published private(set) var stayAwakeEnabled = false
    @Published private(set) var notificationSilencingEnabled = false
    @Published private(set) var nightLightEnabled = false
    @Published private(set) var speedTestRunning = false
    @Published private(set) var networkSpeedSummary = "Run a test to measure this connection."
    @Published private(set) var diskSpeedSummary = "Run a test against the macOS temporary directory."
    @Published private(set) var wifiCredentials: OMacOSWiFiCredentials?
    @Published private(set) var wifiCredentialMessage = "Reading the current network from your login keychain…"
    @Published private(set) var tailscaleStatus: OMacOSTailscaleStatus?
    @Published private(set) var dropboxStatus: OMacOSDropboxStatus?

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

    func refreshWeather() {
        let result = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [projectScript(named: "weather.zsh"), "refresh"]
        )
        if result.exitCode == 0, decodeWeather(from: result.output) {
            weatherMessage = "Forecast refreshed."
        } else {
            weatherMessage = "Weather is unavailable. Check the connection or set a location."
        }
    }

    func refreshMedia() {
        let result = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [projectScript(named: "media.zsh"), "status"]
        )
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(OMacOSMediaStatus.self, from: data) else {
            mediaStatus = nil
            return
        }
        mediaStatus = decoded
    }

    func controlMedia(_ action: String) {
        _ = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [projectScript(named: "media.zsh"), action]
        )
        refreshMedia()
    }

    func toggleMode(_ mode: String) {
        _ = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [projectScript(named: "toggles.zsh"), "toggle", mode]
        )
        refreshToggleStatus()
    }

    func runSystemAction(_ action: String) {
        _ = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [projectScript(named: "toggles.zsh"), action]
        )
    }

    func runSpeedTest(_ kind: String) {
        guard !speedTestRunning else { return }
        speedTestRunning = true
        Task {
            let result = await OMacOSCommandRunner.runAsync(
                executable: "/usr/bin/env",
                arguments: [projectScript(named: "speedtest.zsh"), kind]
            )
            speedTestRunning = false
            guard result.exitCode == 0,
                  let data = result.output.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if kind == "network" {
                    networkSpeedSummary = "The network test failed. Check the connection and try again."
                } else {
                    diskSpeedSummary = "The disk test failed. Check free space and try again."
                }
                return
            }
            if kind == "network" {
                let down = object["downloadMbps"] as? Double ?? 0
                let up = object["uploadMbps"] as? Double ?? 0
                let response = object["responsivenessRPM"] as? Double ?? 0
                networkSpeedSummary = String(format: "%.1f Mbps down  •  %.1f Mbps up  •  %.0f RPM", down, up, response)
            } else {
                let read = object["readMBps"] as? Double ?? 0
                let write = object["writeMBps"] as? Double ?? 0
                diskSpeedSummary = String(format: "%.1f MB/s read  •  %.1f MB/s write", read, write)
            }
        }
    }

    func refreshWiFiCredentials() {
        wifiCredentialMessage = "Reading the current network from your login keychain…"
        Task {
            let result = await OMacOSCommandRunner.runAsync(
                executable: "/usr/bin/env",
                arguments: [projectScript(named: "network.zsh"), "credentials"]
            )
            guard result.exitCode == 0,
                  let data = result.output.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(OMacOSWiFiCredentials.self, from: data) else {
                wifiCredentials = nil
                wifiCredentialMessage = "The connected Wi-Fi password was not available in the login keychain."
                return
            }
            wifiCredentials = decoded
            wifiCredentialMessage = "Scan to join \(decoded.ssid)."
        }
    }

    func refreshService(_ service: String) {
        Task {
            let result = await OMacOSCommandRunner.runAsync(
                executable: "/usr/bin/env",
                arguments: [projectScript(named: "services.zsh"), service, "status"]
            )
            guard result.exitCode == 0, let data = result.output.data(using: .utf8) else { return }
            if service == "tailscale" {
                tailscaleStatus = try? JSONDecoder().decode(OMacOSTailscaleStatus.self, from: data)
            } else if service == "dropbox" {
                dropboxStatus = try? JSONDecoder().decode(OMacOSDropboxStatus.self, from: data)
            }
        }
    }

    func controlService(_ service: String, action: String) {
        Task {
            _ = await OMacOSCommandRunner.runAsync(
                executable: "/usr/bin/env",
                arguments: [projectScript(named: "services.zsh"), service, action]
            )
            refreshService(service)
        }
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
        loadCachedWeather()
        refreshToggleStatus()
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

    private func loadCachedWeather() {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let cachePath = homeDirectory + "/.local/state/omacos/weather.json"
        guard FileManager.default.fileExists(atPath: cachePath) else { return }
        let result = OMacOSCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [projectScript(named: "weather.zsh"), "show"]
        )
        if result.exitCode == 0 {
            _ = decodeWeather(from: result.output)
        }
    }

    @discardableResult
    private func decodeWeather(from output: String) -> Bool {
        guard let data = output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(OMacOSWeatherStatus.self, from: data),
              decoded.schemaVersion == 1 else {
            return false
        }
        weatherStatus = decoded
        return true
    }

    private func refreshToggleStatus() {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let directory = homeDirectory + "/.local/state/omacos/toggles"
        stayAwakeEnabled = FileManager.default.fileExists(atPath: directory + "/stay-awake.enabled")
        notificationSilencingEnabled = FileManager.default.fileExists(atPath: directory + "/notification-silencing.enabled")
        nightLightEnabled = FileManager.default.fileExists(atPath: directory + "/night-light.enabled")
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
