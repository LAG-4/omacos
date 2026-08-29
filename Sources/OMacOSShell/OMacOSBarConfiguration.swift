import Foundation

enum OMacOSBarPosition: String, Codable, CaseIterable {
    case top
    case bottom
}

struct OMacOSBarConfiguration: Codable, Equatable {
    var position: OMacOSBarPosition = .top
    var transparent = false

    static func configurationURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".config/omacos/bar.json")
    }

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> OMacOSBarConfiguration {
        let url = configurationURL(environment: environment)
        guard let data = try? Data(contentsOf: url),
              let configuration = try? JSONDecoder().decode(OMacOSBarConfiguration.self, from: data) else {
            return OMacOSBarConfiguration()
        }
        return configuration
    }

    func save(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        let url = Self.configurationURL(environment: environment)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
