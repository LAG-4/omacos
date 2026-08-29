import Combine
import Foundation

struct OMacOSPluginParityRecord: Codable, Identifiable {
    let id: String
    let name: String
    let grade: String
    let implementation: String
    let limitation: String
}

private struct OMacOSPluginCatalog: Codable {
    let schemaVersion: Int
    let plugins: [OMacOSPluginParityRecord]
}

@MainActor
final class OMacOSPluginCatalogStore: NSObject, ObservableObject {
    @Published private(set) var plugins: [OMacOSPluginParityRecord] = []
    @Published var selectedGrade = "all"

    override init() {
        super.init()
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let candidates = [
            homeDirectory + "/.local/share/omacos/current/config/plugin-catalog.json",
            FileManager.default.currentDirectoryPath + "/config/plugin-catalog.json"
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate) {
            guard let data = FileManager.default.contents(atPath: candidate),
                  let catalog = try? JSONDecoder().decode(OMacOSPluginCatalog.self, from: data),
                  catalog.schemaVersion == 1 else {
                continue
            }
            plugins = catalog.plugins
            break
        }
    }

    var grades: [String] {
        ["all"] + Set(plugins.map(\.grade)).sorted()
    }
}
