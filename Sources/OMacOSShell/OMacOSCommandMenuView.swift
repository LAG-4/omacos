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
    let openPanel: (OMacOSPanelID) -> Void

    private let launchCommands = [
        OMacOSLaunchCommand(id: "terminal", title: "Terminal", subtitle: "Open a new Ghostty window", systemImage: "apple.terminal", executable: "/usr/bin/open", arguments: ["-na", "Ghostty"]),
        OMacOSLaunchCommand(id: "browser", title: "Browser", subtitle: "Open Safari", systemImage: "safari", executable: "/usr/bin/open", arguments: ["-a", "Safari"]),
        OMacOSLaunchCommand(id: "files", title: "Files", subtitle: "Open Finder", systemImage: "folder", executable: "/usr/bin/open", arguments: [NSHomeDirectory()]),
        OMacOSLaunchCommand(id: "settings", title: "System Settings", subtitle: "Configure this Mac", systemImage: "gearshape", executable: "/usr/bin/open", arguments: ["-a", "System Settings"]),
        OMacOSLaunchCommand(id: "activity", title: "Activity Monitor", subtitle: "Inspect running processes", systemImage: "waveform.path.ecg", executable: "/usr/bin/open", arguments: ["-a", "Activity Monitor"])
    ]

    private let panelCommands: [OMacOSPanelID] = [
        .keybindings, .clipboard, .emojis, .capture,
        .reminders, .themes, .wallpapers, .system
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

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Open")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
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
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("OMacOS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(panelCommands) { panelID in
                            Button {
                                openPanel(panelID)
                            } label: {
                                HStack {
                                    Image(systemName: panelID.systemImage)
                                        .foregroundStyle(Color(omacosHex: theme.colors.accent))
                                    Text(panelID.title).fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color(omacosHex: theme.colors.lighterBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .foregroundStyle(Color(omacosHex: theme.colors.foreground))
        .padding(20)
        .frame(width: 540, height: 620)
        .background(Color(omacosHex: theme.colors.darkBackground).opacity(0.98))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(omacosHex: theme.colors.selection), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
