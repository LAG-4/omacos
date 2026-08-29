import SwiftUI

struct OMacOSBarView: View {
    @ObservedObject var barState: OMacOSBarState
    @ObservedObject var agentStore: OMacOSAgentUsageStore
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

            panelButton(.network)
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
        .background(Color(omacosHex: colors.background))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(omacosHex: colors.selection))
                .frame(height: 1)
        }
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
