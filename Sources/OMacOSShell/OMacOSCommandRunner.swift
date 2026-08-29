import Foundation

struct OMacOSCommandResult: Equatable {
    let output: String
    let exitCode: Int32
}

enum OMacOSCommandRunner {
    /// Runs a short local macOS command synchronously for shell status collection.
    static func run(executable: String, arguments: [String]) -> OMacOSCommandResult {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return OMacOSCommandResult(
                output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: process.terminationStatus
            )
        } catch {
            return OMacOSCommandResult(output: "", exitCode: 127)
        }
    }
}

