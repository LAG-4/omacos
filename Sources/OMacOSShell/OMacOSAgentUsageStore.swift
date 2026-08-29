import Combine
import Foundation

struct OMacOSAgentLimit: Codable, Identifiable {
    let label: String?
    let title: String?
    let percent: Double?
    let resetsAt: String?

    var id: String { "\(title ?? label ?? "limit")-\(resetsAt ?? "")" }
    var displayTitle: String { title ?? label ?? "Limit" }
}

struct OMacOSAgentUsageDay: Codable, Identifiable {
    let date: String
    let messageCount: Int?

    var id: String { date }
}

struct OMacOSAgentModelUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?

    var totalTokens: Int {
        (inputTokens ?? 0) + (outputTokens ?? 0) + (cacheReadInputTokens ?? 0) + (cacheCreationInputTokens ?? 0)
    }
}

struct OMacOSAgentBalance: Codable {
    let remaining: Double?
    let funded: Double?
    let spent: Double?
    let currency: String?
    let estimated: Bool?
}

struct OMacOSAgentUsageRecord: Codable, Identifiable {
    let schemaVersion: Int
    let id: String
    let name: String
    let updatedAt: String?
    let ready: Bool?
    let tierLabel: String?
    let usageStatusText: String?
    let authHelpText: String?
    let todayPrompts: Int?
    let todaySessions: Int?
    let todayTotalTokens: Int?
    let totalPrompts: Int?
    let totalSessions: Int?
    let activeDays: Int?
    let limits: [OMacOSAgentLimit]?
    let recentDays: [OMacOSAgentUsageDay]?
    let modelUsage: [String: OMacOSAgentModelUsage]?
    let balance: OMacOSAgentBalance?
}

@MainActor
final class OMacOSAgentUsageStore: NSObject, ObservableObject {
    @Published private(set) var records: [OMacOSAgentUsageRecord] = []
    @Published private(set) var refreshMessage = ""
    @Published var selectedAgentID = ""

    private let usageDirectory: URL
    private let updateCommand: String
    private var reloadTimer: Timer?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        usageDirectory = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/agents/usage")
        let installedCommand = homeDirectory + "/.local/share/omacos/current/bin/omacos-agent-usage-update"
        if FileManager.default.isExecutableFile(atPath: installedCommand) {
            updateCommand = installedCommand
        } else {
            updateCommand = FileManager.default.currentDirectoryPath + "/bin/omacos-agent-usage-update"
        }
        super.init()
        reloadRecords()
    }

    var selectedRecord: OMacOSAgentUsageRecord? {
        records.first { $0.id == selectedAgentID } ?? records.first
    }

    func startMonitoring() {
        reloadTimer = Timer.scheduledTimer(
            timeInterval: 15,
            target: self,
            selector: #selector(reloadRecords),
            userInfo: nil,
            repeats: true
        )
    }

    func refresh() {
        refreshMessage = "Refreshing agent usage…"
        let result = OMacOSCommandRunner.run(executable: "/usr/bin/env", arguments: [updateCommand])
        reloadRecords()
        refreshMessage = result.exitCode == 0 ? "Usage refreshed." : "One or more collectors failed. Existing data is preserved."
    }

    @objc private func reloadRecords() {
        guard let recordURLs = try? FileManager.default.contentsOfDirectory(
            at: usageDirectory,
            includingPropertiesForKeys: nil
        ) else {
            records = []
            return
        }

        records = recordURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let record = try? JSONDecoder().decode(OMacOSAgentUsageRecord.self, from: data),
                      record.schemaVersion == 1,
                      record.ready != false else {
                    return nil
                }
                return record
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if !records.contains(where: { $0.id == selectedAgentID }) {
            selectedAgentID = records.first?.id ?? ""
        }
    }
}
