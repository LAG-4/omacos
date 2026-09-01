import SwiftUI

struct OMacOSBarView: View {
    @ObservedObject var barState: OMacOSBarState
    @ObservedObject var systemState: OMacOSSystemPanelState
    @ObservedObject var agentStore: OMacOSAgentUsageStore
    @ObservedObject var dictationController: OMacOSDictationController
    let configuration: OMacOSBarConfiguration
    let togglePanel: (OMacOSPanelID) -> Void

    private var colors: OMacOSThemeColors { barState.theme.colors }
    private let contract = OMacOSShellContract.shared

    var body: some View {
        Group {
            if configuration.position.isVertical {
                verticalBar
            } else {
                horizontalBar
            }
        }
        .font(quattroFont(size: contract.typography.body))
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
        ZStack {
            HStack(spacing: 0) {
                menuButton
                workspaceButtons
                Spacer(minLength: 0)
                horizontalRightModules
            }

            HStack(spacing: 0) {
                modeIndicators
                clockButton
                if systemState.weatherStatus != nil {
                    panelButton(.weather)
                }
            }
        }
        .padding(.horizontal, CGFloat(contract.spacing.sm))
    }

    private var horizontalRightModules: some View {
        HStack(spacing: 0) {
            if !agentStore.records.isEmpty {
                panelButton(.agents)
            }
            panelButton(.bluetooth)
            panelButton(.network)
            panelButton(.audio)
            panelButton(.display)
            powerButton
        }
    }

    private var verticalBar: some View {
        VStack(spacing: 0) {
            menuButton
            verticalWorkspaceButtons
            Spacer(minLength: CGFloat(contract.spacing.lg))
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
            panelButton(.audio)
            panelButton(.display)
            if !agentStore.records.isEmpty {
                panelButton(.agents)
            }
            powerButton
            clockButton
        }
        .padding(.vertical, CGFloat(contract.spacing.sm))
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
                .font(quattroFont(size: contract.typography.body, weight: .bold))
                .foregroundStyle(Color(omacosHex: colors.foreground))
                .frame(
                    width: configuration.position.isVertical
                        ? CGFloat(contract.bar.verticalSize)
                        : CGFloat(contract.bar.iconSlot),
                    height: configuration.position.isVertical
                        ? CGFloat(contract.bar.iconSlot)
                        : CGFloat(contract.bar.horizontalSize)
                )
        }
        .buttonStyle(.plain)
        .help("OMacOS menu")
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
        HStack(spacing: 1) {
            ForEach(barState.visibleWorkspaces, id: \.self) { workspace in
                Button {
                    barState.focusWorkspace(workspace)
                } label: {
                    Text(workspace == barState.activeWorkspace ? "\u{F14FB}" : workspace)
                        .font(quattroFont(size: contract.typography.body, weight: .medium))
                        .frame(width: 20, height: CGFloat(contract.bar.horizontalSize))
                        .foregroundStyle(Color(omacosHex: colors.foreground))
                        .opacity(workspace == barState.activeWorkspace ? 1 : 0.5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var verticalWorkspaceButtons: some View {
        VStack(spacing: CGFloat(contract.spacing.xxs)) {
            ForEach(barState.visibleWorkspaces, id: \.self) { workspace in
                Button {
                    barState.focusWorkspace(workspace)
                } label: {
                    Text(workspace == barState.activeWorkspace ? "\u{F14FB}" : workspace)
                        .font(quattroFont(size: contract.typography.body, weight: .medium))
                        .frame(width: CGFloat(contract.bar.verticalSize), height: 20)
                        .foregroundStyle(Color(omacosHex: colors.foreground))
                        .opacity(workspace == barState.activeWorkspace ? 1 : 0.5)
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
                .font(.system(size: CGFloat(contract.bar.iconFont)))
                .frame(
                    width: configuration.position.isVertical
                        ? CGFloat(contract.bar.verticalSize)
                        : CGFloat(contract.bar.statusSlot),
                    height: configuration.position.isVertical
                        ? CGFloat(contract.bar.statusSlot)
                        : CGFloat(contract.bar.horizontalSize)
                )
        }
        .buttonStyle(.plain)
        .help(panelID.title)
    }

    private var powerButton: some View {
        Button { togglePanel(.power) } label: {
            if configuration.position.isVertical {
                Image(systemName: "battery.75percent")
                    .font(.system(size: CGFloat(contract.bar.iconFont)))
                    .frame(width: CGFloat(contract.bar.verticalSize), height: CGFloat(contract.bar.statusSlot))
            } else {
                HStack(spacing: CGFloat(contract.spacing.xxs)) {
                    Image(systemName: "battery.75percent")
                    if !barState.batteryText.isEmpty {
                        Text(barState.batteryText)
                    }
                }
                .font(quattroFont(size: contract.typography.bodySmall))
                .frame(height: CGFloat(contract.bar.horizontalSize))
            }
        }
        .buttonStyle(.plain)
        .help(barState.batteryText)
    }

    private var clockButton: some View {
        Button { togglePanel(.clock) } label: {
            if configuration.position.isVertical {
                Image(systemName: "clock")
                    .font(.system(size: CGFloat(contract.bar.iconFont)))
                    .frame(width: CGFloat(contract.bar.verticalSize), height: CGFloat(contract.bar.statusSlot))
            } else {
                Text(barState.clockText)
                    .font(quattroFont(size: contract.typography.body, weight: .medium))
                    .padding(.horizontal, CGFloat(contract.spacing.sm))
                    .frame(height: CGFloat(contract.bar.horizontalSize))
            }
        }
        .buttonStyle(.plain)
        .help(barState.clockText)
    }

    private func quattroFont(size: Int, weight: Font.Weight = .regular) -> Font {
        .custom(OMacOSShellContract.shared.typography.family, size: CGFloat(size)).weight(weight)
    }
}
