import Combine
import Foundation

struct OMacOSReminder: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let dueAt: Date
    var delivered: Bool
}

@MainActor
final class OMacOSReminderStore: NSObject, ObservableObject {
    @Published private(set) var reminders: [OMacOSReminder] = []
    @Published var draftText = ""
    @Published var draftDate = Date(timeIntervalSinceNow: 600)

    private let remindersURL: URL
    private let notificationSilencingURL: URL
    private let notificationStore: OMacOSNotificationStore?
    private var deliveryTimer: Timer?

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        notificationStore: OMacOSNotificationStore? = nil
    ) {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        remindersURL = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/reminders.json")
        notificationSilencingURL = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".local/state/omacos/toggles/notification-silencing.enabled")
        self.notificationStore = notificationStore
        super.init()
        loadReminders()
    }

    func startDelivery() {
        deliverDueReminders()
        deliveryTimer = Timer.scheduledTimer(
            timeInterval: 15,
            target: self,
            selector: #selector(deliverDueReminders),
            userInfo: nil,
            repeats: true
        )
    }

    @discardableResult
    func add(text: String, dueAt: Date) -> OMacOSReminder? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        let reminder = OMacOSReminder(id: UUID(), text: normalizedText, dueAt: dueAt, delivered: false)
        reminders.append(reminder)
        reminders.sort { $0.dueAt < $1.dueAt }
        persistReminders()
        return reminder
    }

    func addDraft() {
        guard add(text: draftText, dueAt: draftDate) != nil else { return }
        draftText = ""
        draftDate = Date(timeIntervalSinceNow: 600)
    }

    func remove(id: UUID) {
        reminders.removeAll { $0.id == id }
        persistReminders()
    }

    func clear() {
        reminders = []
        persistReminders()
    }

    @objc func deliverDueReminders() {
        let now = Date()
        var changed = false
        for index in reminders.indices where !reminders[index].delivered && reminders[index].dueAt <= now {
            notificationStore?.add(title: "OMacOS Reminder", body: reminders[index].text, source: "reminder")
            if !FileManager.default.fileExists(atPath: notificationSilencingURL.path) {
                Self.deliverNotification(text: reminders[index].text)
            }
            reminders[index].delivered = true
            changed = true
        }
        if changed {
            persistReminders()
        }
    }

    private func loadReminders() {
        guard let data = try? Data(contentsOf: remindersURL),
              let decodedReminders = try? JSONDecoder().decode([OMacOSReminder].self, from: data) else {
            return
        }
        reminders = decodedReminders.sorted { $0.dueAt < $1.dueAt }
    }

    private func persistReminders() {
        do {
            try FileManager.default.createDirectory(
                at: remindersURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(reminders)
            try data.write(to: remindersURL, options: .atomic)
        } catch {
            // Reminder persistence failures must not crash the desktop shell.
        }
    }

    nonisolated private static func deliverNotification(text: String) {
        _ = OMacOSCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: [
                "-e", "on run argv",
                "-e", "display notification (item 1 of argv) with title \"OMacOS Reminder\"",
                "-e", "end run",
                text
            ]
        )
    }
}
