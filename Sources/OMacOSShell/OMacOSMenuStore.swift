import Combine
import Foundation

struct OMacOSMenuEntry: Codable, Identifiable {
    let id: String
    let label: String
    let referenceKind: String

    var parentID: String? {
        guard let separator = id.lastIndex(of: ".") else { return nil }
        return String(id[..<separator])
    }
}

private struct OMacOSQuattroInventory: Codable {
    let schemaVersion: Int
    let menuEntries: [OMacOSMenuEntry]
}

@MainActor
final class OMacOSMenuStore: ObservableObject {
    @Published private(set) var entries: [OMacOSMenuEntry] = []
    @Published var currentMenuID: String?
    @Published var searchText = ""
    @Published private(set) var actionMessage = ""
    @Published private(set) var actionRunning = false

    private let omacosCLI: String

    init(
        initialMenuID: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        currentMenuID = initialMenuID
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let installedRoot = homeDirectory + "/.local/share/omacos/current"
        let projectRoot = FileManager.default.fileExists(atPath: installedRoot)
            ? installedRoot
            : FileManager.default.currentDirectoryPath
        omacosCLI = FileManager.default.isExecutableFile(atPath: homeDirectory + "/.local/bin/omacos")
            ? homeDirectory + "/.local/bin/omacos"
            : projectRoot + "/bin/omacos"
        let inventoryCandidates = [
            projectRoot + "/docs/quattro-inventory.json",
            Bundle.module.url(forResource: "quattro-inventory", withExtension: "json")?.path
        ].compactMap { $0 }
        for candidate in inventoryCandidates where entries.isEmpty {
            loadInventory(at: candidate)
        }
    }

    var visibleEntries: [OMacOSMenuEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return entries.filter {
                $0.label.localizedCaseInsensitiveContains(query)
                    || $0.id.localizedCaseInsensitiveContains(query)
            }
        }
        return entries.filter { $0.parentID == currentMenuID }
    }

    var currentTitle: String {
        guard let currentMenuID,
              let entry = entries.first(where: { $0.id == currentMenuID }) else {
            return "Command menu"
        }
        return entry.label
    }

    func hasChildren(_ entry: OMacOSMenuEntry) -> Bool {
        entries.contains { $0.parentID == entry.id }
    }

    func open(_ entry: OMacOSMenuEntry) {
        currentMenuID = entry.id
        searchText = ""
        actionMessage = ""
    }

    func navigateBack() {
        guard let currentMenuID,
              let separator = currentMenuID.lastIndex(of: ".") else {
            self.currentMenuID = nil
            return
        }
        self.currentMenuID = String(currentMenuID[..<separator])
        actionMessage = ""
    }

    func execute(_ entry: OMacOSMenuEntry) async -> Bool {
        guard !actionRunning else { return false }
        actionRunning = true
        actionMessage = "Running \(entry.label)…"
        let result = await OMacOSCommandRunner.runAsync(
            executable: omacosCLI,
            arguments: ["menu", "run", entry.id]
        )
        actionRunning = false
        if result.exitCode == 0 {
            actionMessage = result.output.isEmpty ? "Done." : result.output
            return true
        }
        actionMessage = result.output.isEmpty
            ? "This item does not have a safe macOS implementation."
            : result.output
        return false
    }

    private func loadInventory(at path: String) {
        guard let data = FileManager.default.contents(atPath: path),
              let inventory = try? JSONDecoder().decode(OMacOSQuattroInventory.self, from: data),
              inventory.schemaVersion == 1 else {
            return
        }
        entries = inventory.menuEntries
    }
}
