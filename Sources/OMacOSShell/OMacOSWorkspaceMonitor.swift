import Foundation

private struct OMacOSAeroSpaceWorkspaceEvent: Decodable {
    let workspace: String
}

@MainActor
final class OMacOSWorkspaceMonitor {
    private let environment: [String: String]
    private let workspaceChanged: (String) -> Void
    private var eventProcess: Process?
    private var eventPipe: Pipe?
    private var outputBuffer = ""

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        workspaceChanged: @escaping (String) -> Void
    ) {
        self.environment = environment
        self.workspaceChanged = workspaceChanged
    }

    /// Starts one persistent AeroSpace event stream; other adapters keep the polling fallback.
    func start() {
        guard eventProcess == nil,
              activeWindowManagerProfile() == "aerospace",
              let aerospaceExecutableURL else {
            return
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = aerospaceExecutableURL
        process.arguments = ["subscribe", "focused-workspace-changed", "--no-send-initial"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.receiveEventData(data)
            }
        }

        do {
            try process.run()
            eventProcess = process
            eventPipe = pipe
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
    }

    /// Stops the active event stream without changing the selected window manager.
    func stop() {
        eventPipe?.fileHandleForReading.readabilityHandler = nil
        if eventProcess?.isRunning == true {
            eventProcess?.terminate()
        }
        eventPipe = nil
        eventProcess = nil
        outputBuffer = ""
    }

    /// Parses one JSON line emitted by `aerospace subscribe focused-workspace-changed`.
    nonisolated static func workspace(fromEventLine line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(OMacOSAeroSpaceWorkspaceEvent.self, from: data),
              !event.workspace.isEmpty else {
            return nil
        }
        return event.workspace
    }

    private func receiveEventData(_ data: Data) {
        outputBuffer += String(decoding: data, as: UTF8.self)
        while let newlineIndex = outputBuffer.firstIndex(of: "\n") {
            let line = String(outputBuffer[..<newlineIndex])
            outputBuffer.removeSubrange(...newlineIndex)
            if let workspace = Self.workspace(fromEventLine: line) {
                workspaceChanged(workspace)
            }
        }
    }

    private func activeWindowManagerProfile() -> String {
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let profilePath = homeDirectory + "/.config/omacos/window-manager-profile"
        guard let profile = try? String(contentsOfFile: profilePath, encoding: .utf8) else {
            return "aerospace"
        }
        return profile.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var aerospaceExecutableURL: URL? {
        let candidates = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace"
        ]
        guard let executable = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            return nil
        }
        return URL(fileURLWithPath: executable)
    }
}
