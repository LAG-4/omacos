import Combine
import Foundation

struct OMacOSNotificationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let source: String
    let createdAt: Date
}

@MainActor
final class OMacOSNotificationStore: NSObject, ObservableObject {
    @Published private(set) var records: [OMacOSNotificationRecord] = []

    private let historyURL: URL

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        historyURL = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/notification-history.json")
        super.init()
        loadHistory()
    }

    @discardableResult
    func add(title: String, body: String, source: String) -> OMacOSNotificationRecord? {
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else { return nil }
        let record = OMacOSNotificationRecord(
            id: UUID(),
            title: title,
            body: normalizedBody,
            source: source,
            createdAt: Date()
        )
        records.insert(record, at: 0)
        if records.count > 200 {
            records.removeLast(records.count - 200)
        }
        persistHistory()
        return record
    }

    func clear() {
        records = []
        persistHistory()
    }

    @discardableResult
    func dismissMostRecent() -> OMacOSNotificationRecord? {
        guard !records.isEmpty else { return nil }
        let record = records.removeFirst()
        persistHistory()
        return record
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([OMacOSNotificationRecord].self, from: data) else {
            return
        }
        records = Array(decoded.prefix(200))
    }

    private func persistHistory() {
        do {
            try FileManager.default.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // Notification history must never bring down the desktop shell.
        }
    }
}
