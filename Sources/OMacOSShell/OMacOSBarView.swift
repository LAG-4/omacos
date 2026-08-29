import SwiftUI

struct OMacOSBarView: View {
    @ObservedObject var barState: OMacOSBarState

    private var colors: OMacOSThemeColors { barState.theme.colors }

    var body: some View {
        HStack(spacing: 12) {
            Text("OM")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color(omacosHex: colors.background))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(omacosHex: colors.accent))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            workspaceButtons

            Text(barState.frontmostApplication)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(omacosHex: colors.lightForeground))
                .lineLimit(1)

            Spacer(minLength: 12)

            if !barState.batteryText.isEmpty {
                Label(barState.batteryText, systemImage: "battery.75percent")
            }

            Text(barState.clockText)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
}
