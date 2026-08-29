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
        HStack(spacing: 12) {
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
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color(omacosHex: colors.foreground))
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(omacosHex: colors.background)
                .opacity(configuration.transparent ? 0.76 : 1)
        )
        .overlay(alignment: configuration.position == .top ? .bottom : .top) {
            Rectangle()
                .fill(Color(omacosHex: colors.selection))
                .frame(height: 1)
        }
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
            modeButton("notification-silencing", systemImage: "bell.slash.fill", help: "Notification silencing")
        }
        if systemState.nightLightEnabled {
            modeButton("night-light", systemImage: "moon.fill", help: "Night light reminder")
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
