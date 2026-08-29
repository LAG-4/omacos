import SwiftUI

struct OMacOSSystemPanelView: View {
    let panelID: OMacOSPanelID
    let theme: OMacOSTheme
    @ObservedObject var state: OMacOSSystemPanelState
    let dismissPanel: () -> Void

    private var colors: OMacOSThemeColors { theme.colors }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelHeader
            Divider().overlay(Color(omacosHex: colors.selection))
            panelContents
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(omacosHex: colors.foreground))
        .padding(18)
        .frame(width: panelWidth, height: panelHeight)
        .background(Color(omacosHex: colors.darkBackground).opacity(0.98))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(omacosHex: colors.selection), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: panelID.systemImage)
                .foregroundStyle(Color(omacosHex: colors.accent))
            Text(panelID.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            Button {
                state.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(omacosHex: colors.darkForeground))
            Button(action: dismissPanel) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(omacosHex: colors.darkForeground))
        }
    }

    @ViewBuilder private var panelContents: some View {
        switch panelID {
        case .keybindings:
            keybindingsPanel
        case .system:
            systemPanel
        case .audio:
            audioPanel
        case .bluetooth:
            bluetoothPanel
        case .network:
            networkPanel
        case .display:
            displayPanel
        case .clock:
            clockPanel
        case .power:
            powerPanel
        case .activity:
            activityPanel
        case .menu:
            EmptyView()
        }
    }

    private var keybindingsPanel: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(state.keybindings) { binding in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(binding.displayChord)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(omacosHex: colors.accent))
                            .frame(width: 190, alignment: .leading)
                        Text(binding.description)
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    Divider().overlay(Color(omacosHex: colors.selection).opacity(0.5))
                }
            }
        }
        .overlay {
            if state.keybindings.isEmpty {
                ContentUnavailableView("No keybindings found", systemImage: "keyboard")
            }
        }
    }

    private var systemPanel: some View {
        VStack(spacing: 10) {
            panelAction("Lock", subtitle: "Show the macOS login window", systemImage: "lock") { state.lockMac() }
            panelAction("Sleep", subtitle: "Put this Mac to sleep", systemImage: "moon.zzz") { state.sleepMac() }
            panelAction("System Settings", subtitle: "Open macOS settings", systemImage: "gearshape") { state.openSystemSettings() }
        }
    }

    private var audioPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.outputMuted ? "Output muted" : "Output volume \(state.volumePercentage)%")
                .font(.system(size: 15, weight: .semibold))
            Slider(
                value: Binding(
                    get: { Double(state.volumePercentage) },
                    set: { state.setOutputVolume(Int($0.rounded())) }
                ),
                in: 0...100,
                step: 1
            )
            HStack {
                Button(state.outputMuted ? "Unmute" : "Mute") { state.toggleOutputMute() }
                Spacer()
                Button("Sound Settings") { state.openSystemSettings("x-apple.systempreferences:com.apple.Sound-Settings.extension") }
            }
        }
        .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
    }

    private var bluetoothPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard(state.bluetoothState, detail: "Device connections remain controlled by macOS.", systemImage: "bolt.horizontal.circle")
            panelAction("Bluetooth Settings", subtitle: "Pair, connect, and manage devices", systemImage: "gear") {
                state.openSystemSettings("x-apple.systempreferences:com.apple.BluetoothSettings")
            }
        }
    }

    private var networkPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard(state.networkName, detail: "Current Wi-Fi network", systemImage: "wifi")
            panelAction("Wi-Fi Settings", subtitle: "Join networks and configure services", systemImage: "network") {
                state.openSystemSettings("x-apple.systempreferences:com.apple.wifi-settings-extension")
            }
        }
    }

    private var displayPanel: some View {
        VStack(spacing: 10) {
            ForEach(NSScreen.screens.indices, id: \.self) { index in
                statusCard(
                    NSScreen.screens[index].localizedName,
                    detail: "\(Int(NSScreen.screens[index].frame.width)) × \(Int(NSScreen.screens[index].frame.height)) points",
                    systemImage: index == 0 ? "display" : "rectangle.on.rectangle"
                )
            }
            panelAction("Display Settings", subtitle: "Resolution, arrangement, and brightness", systemImage: "slider.horizontal.3") {
                state.openSystemSettings("x-apple.systempreferences:com.apple.Displays-Settings.extension")
            }
        }
    }

    private var clockPanel: some View {
        VStack(spacing: 12) {
            DatePicker("", selection: .constant(Date()), displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Color(omacosHex: colors.accent))
            panelAction("Open Calendar", subtitle: "View events in Apple Calendar", systemImage: "calendar") {
                state.openApplication("Calendar")
            }
        }
    }

    private var powerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard(state.batteryPercentage, detail: state.batterySource, systemImage: "battery.75percent")
            statusCard(state.uptimeSummary, detail: "Current session", systemImage: "clock.arrow.circlepath")
            panelAction("Battery Settings", subtitle: "Energy mode and battery health", systemImage: "leaf") {
                state.openSystemSettings("x-apple.systempreferences:com.apple.Battery-Settings.extension")
            }
        }
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard(state.systemLoad, detail: "1, 5, and 15 minute load average", systemImage: "cpu")
            statusCard(state.memorySummary, detail: state.uptimeSummary, systemImage: "memorychip")
            panelAction("Activity Monitor", subtitle: "Inspect processes, CPU, memory, disk, and network", systemImage: "waveform.path.ecg") {
                state.openApplication("Activity Monitor")
            }
        }
    }

    private func statusCard(_ title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(Color(omacosHex: colors.accent))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
            Spacer()
        }
        .padding(12)
        .background(Color(omacosHex: colors.lighterBackground))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func panelAction(_ title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color(omacosHex: colors.accent))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(omacosHex: colors.darkForeground))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
            .padding(11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(omacosHex: colors.lighterBackground))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var panelWidth: CGFloat {
        panelID == .keybindings ? 620 : 430
    }

    private var panelHeight: CGFloat {
        switch panelID {
        case .keybindings: 620
        case .clock: 520
        default: 360
        }
    }
}

private struct OMacOSPanelButtonStyle: ButtonStyle {
    let theme: OMacOSTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(Color(omacosHex: theme.colors.foreground))
            .background(Color(omacosHex: configuration.isPressed ? theme.colors.selection : theme.colors.lighterBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
