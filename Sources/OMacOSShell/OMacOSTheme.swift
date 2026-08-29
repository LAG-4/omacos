import AppKit
import Foundation
import SwiftUI

struct OMacOSTheme: Codable, Equatable {
    let schemaVersion: Int
    let name: String
    let slug: String
    let mode: String
    let colors: OMacOSThemeColors

    /// Loads the generated semantic theme, then falls back to the bundled Tokyo Night theme.
    static func loadCurrentTheme(environment: [String: String] = ProcessInfo.processInfo.environment) -> OMacOSTheme {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let generatedThemeURL = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".config/omacos/generated/shell-theme.json")

        if let theme = try? decodeTheme(at: generatedThemeURL) {
            return theme
        }

        guard let bundledURL = Bundle.module.url(forResource: "default-theme", withExtension: "json"),
              let theme = try? decodeTheme(at: bundledURL) else {
            fatalError("OMacOS theme load failed: bundled default-theme.json is missing or invalid")
        }
        return theme
    }

    /// Decodes one semantic theme file and rejects unsupported schema versions.
    static func decodeTheme(at url: URL) throws -> OMacOSTheme {
        let data = try Data(contentsOf: url)
        let theme = try JSONDecoder().decode(OMacOSTheme.self, from: data)
        guard theme.schemaVersion == 1 else {
            throw OMacOSThemeError.unsupportedSchemaVersion(theme.schemaVersion)
        }
        return theme
    }
}

struct OMacOSThemeColors: Codable, Equatable {
    let accent: String
    let selection: String
    let muted: String
    let background: String
    let darkBackground: String
    let darkerBackground: String
    let lighterBackground: String
    let foreground: String
    let darkForeground: String
    let lightForeground: String
    let brightForeground: String
    let red: String
    let yellow: String
    let orange: String
    let green: String
    let cyan: String
    let blue: String
    let magenta: String
}

enum OMacOSThemeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

extension Color {
    /// Creates a SwiftUI color from a six-digit semantic theme hex value.
    init(omacosHex: String) {
        let trimmedHex = omacosHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmedHex).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

