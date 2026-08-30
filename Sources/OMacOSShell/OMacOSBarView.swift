import SwiftUI

struct OMacOSBarView: View {
    @ObservedObject var barState: OMacOSBarState
    @ObservedObject var systemState: OMacOSSystemPanelState
    @ObservedObject var agentStore: OMacOSAgentUsageStore
    @ObservedObject var dictationController: OMacOSDictationController
    let configuration: OMacOSBarConfiguration
    let togglePanel: (OMacOSPanelID) -> Void

    private var colors: OMacOSThemeColors { barState.theme.colors }

    var body: some View {
        Group {
            if configuration.position.isVertical {
                verticalBar
            } else {
                horizontalBar
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color(omacosHex: colors.foreground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(omacosHex: colors.background)
                .opacity(configuration.transparent ? 0.76 : 1)
        )
        .overlay(alignment: borderAlignment) {
            Rectangle()
                .fill(Color(omacosHex: colors.selection))
                .frame(
                    width: configuration.position.isVertical ? 1 : nil,
                    height: configuration.position.isVertical ? nil : 1
                )
        }
    }

    private var horizontalBar: some View {
        HStack(spacing: 12) {
            menuButton

            workspaceButtons

            Text(barState.frontmostApplication)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(omacosHex: colors.lightForeground))
                .lineLimit(1)

            Spacer(minLength: 12)

            modeIndicators

            if let weather = systemState.weatherStatus {
                Button { togglePanel(.weather) } label: {
                    Label("\(weather.temperatureC)°", systemImage: "cloud.sun")
                }
                .buttonStyle(.plain)
            }

            if systemState.mediaStatus?.hasTrack == true {
                Button { systemState.controlMedia("play-pause") } label: {
                    Image(systemName: systemState.mediaStatus?.isPlaying == true ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .help(systemState.mediaStatus?.title ?? "Now Playing")
            }

            panelButton(.network)
            if systemState.tailscaleStatus?.installed == true {
                panelButton(.tailscale)
            }
            panelButton(.audio)
            if !agentStore.records.isEmpty {
                panelButton(.agents)
            }

            if !barState.batteryText.isEmpty {
                Button {
                    togglePanel(.power)
                } label: {
                    Label(barState.batteryText, systemImage: "battery.75percent")
                }
                .buttonStyle(.plain)
            }

            Button {
                togglePanel(.clock)
            } label: {
                Text(barState.clockText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
    }

    private var verticalBar: some View {
        VStack(spacing: 9) {
            menuButton
            verticalWorkspaceButtons

            Text(String(barState.frontmostApplication.prefix(2)).uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(omacosHex: colors.lightForeground))
                .help(barState.frontmostApplication)

            Spacer(minLength: 8)
            modeIndicators

            if systemState.weatherStatus != nil {
                panelButton(.weather)
            }
            if systemState.mediaStatus?.hasTrack == true {
                Button { systemState.controlMedia("play-pause") } label: {
                    Image(systemName: systemState.mediaStatus?.isPlaying == true ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .help(systemState.mediaStatus?.title ?? "Now Playing")
            }
            panelButton(.network)
            if systemState.tailscaleStatus?.installed == true {
                panelButton(.tailscale)
            }
            panelButton(.audio)
            if !agentStore.records.isEmpty {
                panelButton(.agents)
            }
            if !barState.batteryText.isEmpty {
                Button { togglePanel(.power) } label: {
                    Image(systemName: "battery.75percent")
                }
                .buttonStyle(.plain)
                .help(barState.batteryText)
            }
            Button { togglePanel(.clock) } label: {
                Image(systemName: "clock")
            }
            .buttonStyle(.plain)
            .help(barState.clockText)
        }
        .padding(.vertical, 10)
    }

    private var borderAlignment: Alignment {
        switch configuration.position {
        case .top: .bottom
        case .bottom: .top
        case .left: .trailing
        case .right: .leading
        }
    }

    private var menuButton: some View {
        Button {
            togglePanel(.menu)
        } label: {
            Text("OM")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color(omacosHex: colors.background))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(omacosHex: colors.accent))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var modeIndicators: some View {
        if dictationController.isRecording {
            Button { dictationController.stopAndInsert() } label: {
                Image(systemName: "waveform.and.mic")
                    .foregroundStyle(Color(omacosHex: colors.red))
            }
            .buttonStyle(.plain)
            .help("Stop dictation and insert")
        }
        if systemState.notificationSilencingEnabled {
            modeButton("notification-silencing", systemImage: "bell.slash.fill", help: "OMacOS reminders paused")
        }
        if systemState.stayAwakeEnabled {
            modeButton("stay-awake", systemImage: "cup.and.saucer.fill", help: "Stay awake")
        }
    }

    private func modeButton(_ mode: String, systemImage: String, help: String) -> some View {
        Button { systemState.toggleMode(mode) } label: {
            Image(systemName: systemImage)
                .foregroundStyle(Color(omacosHex: colors.accent))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var workspaceButtons: some View {
        HStack(spacing: 3) {
            ForEach(barState.visibleWorkspaces, id: \.self) { workspace in
                Button {
                    barState.focusWorkspace(workspace)
                } label: {
                    Text(workspace)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 22, height: 22)
                        .foregroundStyle(
                            workspace == barState.activeWorkspace
                                ? Color(omacosHex: colors.background)
                                : Color(omacosHex: colors.darkForeground)
                        )
                        .background(
                            workspace == barState.activeWorkspace
                                ? Color(omacosHex: colors.accent)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var verticalWorkspaceButtons: some View {
        VStack(spacing: 2) {
            ForEach(barState.visibleWorkspaces, id: \.self) { workspace in
                Button {
                    barState.focusWorkspace(workspace)
                } label: {
                    Text(workspace)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(width: 24, height: 20)
                        .foregroundStyle(
                            workspace == barState.activeWorkspace
                                ? Color(omacosHex: colors.background)
                                : Color(omacosHex: colors.darkForeground)
                        )
                        .background(
                            workspace == barState.activeWorkspace
                                ? Color(omacosHex: colors.accent)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func panelButton(_ panelID: OMacOSPanelID) -> some View {
        Button {
            togglePanel(panelID)
        } label: {
            Image(systemName: panelID.systemImage)
                .frame(width: 16, height: 18)
        }
        .buttonStyle(.plain)
    }
}
