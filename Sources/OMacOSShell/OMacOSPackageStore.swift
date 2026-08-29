import Combine
import Foundation

struct OMacOSOptionalPackage: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let type: String
    let package: String
    let description: String
}

private struct OMacOSOptionalPackageCatalog: Codable {
    let schemaVersion: Int
    let packages: [OMacOSOptionalPackage]
}

@MainActor
final class OMacOSPackageStore: NSObject, ObservableObject {
    @Published private(set) var packages: [OMacOSOptionalPackage] = []
    @Published private(set) var installedPackageIDs: Set<String> = []
    @Published private(set) var workingPackageID = ""
    @Published private(set) var statusMessage = ""
    @Published var selectedCategory = "all"

    private let installedRoot: String

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let installedCandidate = homeDirectory + "/.local/share/omacos/current"
        installedRoot = FileManager.default.fileExists(atPath: installedCandidate)
            ? installedCandidate
            : FileManager.default.currentDirectoryPath
        super.init()
        loadCatalog()
    }

    var categories: [String] {
        ["all"] + Set(packages.map(\.category)).sorted()
    }

    func refreshInstalledPackages() {
        Task {
            let result = await OMacOSCommandRunner.runAsync(
                executable: "/usr/bin/env",
                arguments: ["brew", "list", "--cask", "-1"]
            )
            let installedNames = Set(result.output.split(separator: "\n").map(String.init))
            installedPackageIDs = Set(packages.filter { installedNames.contains($0.package) }.map(\.id))
        }
    }

    func toggleInstallation(_ package: OMacOSOptionalPackage) {
        guard workingPackageID.isEmpty else { return }
        let action = installedPackageIDs.contains(package.id) ? "remove" : "install"
        workingPackageID = package.id
        statusMessage = "\(action == "install" ? "Installing" : "Removing") \(package.name)…"
        Task {
            let result = await OMacOSCommandRunner.runAsync(
                executable: "/usr/bin/env",
                arguments: [installedRoot + "/scripts/packages.zsh", action, package.id, "--yes"]
            )
            workingPackageID = ""
            statusMessage = result.exitCode == 0
                ? "\(package.name) \(action == "install" ? "installed" : "removed")."
                : "Could not \(action) \(package.name). Open a terminal for Homebrew details."
            refreshInstalledPackages()
        }
    }

    private func loadCatalog() {
        let catalogURL = URL(fileURLWithPath: installedRoot).appendingPathComponent("config/optional-packages.json")
        guard let data = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode(OMacOSOptionalPackageCatalog.self, from: data),
              catalog.schemaVersion == 1 else {
            return
        }
        packages = catalog.packages
    }
}
