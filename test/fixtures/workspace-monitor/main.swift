import Foundation

let event = #"{"_event":"focused-workspace-changed","prevWorkspace":"1","workspace":"2"}"#

guard OMacOSWorkspaceMonitor.workspace(fromEventLine: event) == "2",
      OMacOSWorkspaceMonitor.workspace(fromEventLine: "not-json") == nil,
      OMacOSWorkspaceMonitor.workspace(fromEventLine: #"{"workspace":""}"#) == nil else {
    fputs("Workspace event parsing failed.\n", stderr)
    exit(1)
}

print("Workspace event monitor test passed")
