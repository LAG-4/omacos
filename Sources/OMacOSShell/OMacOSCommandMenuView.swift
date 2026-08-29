import AppKit
import SwiftUI

struct OMacOSLaunchCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let executable: String
    let arguments: [String]
}

struct OMacOSCommandMenuView: View {
    let theme: OMacOSTheme
    let dismissMenu: () -> Void

    private let launchCommands = [
        OMacOSLaunchCommand(id: "terminal", title: "Terminal", subtitle: "Open a new Ghostty window", systemImage: "apple.terminal", executable: "/usr/bin/open", arguments: ["-na", "Ghostty"]),
        OMacOSLaunchCommand(id: "browser", title: "Browser", subtitle: "Open Safari", systemImage: "safari", executable: "/usr/bin/open", arguments: ["-a", "Safari"]),
        OMacOSLaunchCommand(id: "files", title: "Files", subtitle: "Open Finder", systemImage: "folder", executable: "/usr/bin/open", arguments: [NSHomeDirectory()]),
        OMacOSLaunchCommand(id: "settings", title: "System Settings", subtitle: "Configure this Mac", systemImage: "gearshape", executable: "/usr/bin/open", arguments: ["-a", "System Settings"]),
        OMacOSLaunchCommand(id: "activity", title: "Activity Monitor", subtitle: "Inspect running processes", systemImage: "waveform.path.ecg", executable: "/usr/bin/open", arguments: ["-a", "Activity Monitor"])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OMacOS")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Command menu")
                        .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
                }
                Spacer()
                Text("Right Option + Space")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
            }

            Divider().overlay(Color(omacosHex: theme.colors.selection))

            ForEach(launchCommands) { command in
                Button {
                    _ = OMacOSCommandRunner.run(executable: command.executable, arguments: command.arguments)
                    dismissMenu()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: command.systemImage)
                            .frame(width: 24)
                            .foregroundStyle(Color(omacosHex: theme.colors.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.title).fontWeight(.semibold)
                            Text(command.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Color(omacosHex: theme.colors.foreground))
        .padding(20)
        .frame(width: 520, height: 390)
        .background(Color(omacosHex: theme.colors.darkBackground).opacity(0.98))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(omacosHex: theme.colors.selection), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

