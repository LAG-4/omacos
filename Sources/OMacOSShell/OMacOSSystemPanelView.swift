import CoreImage.CIFilterBuiltins
import SwiftUI

struct OMacOSSystemPanelView: View {
    let panelID: OMacOSPanelID
    let theme: OMacOSTheme
    @ObservedObject var state: OMacOSSystemPanelState
    @ObservedObject var clipboardStore: OMacOSClipboardStore
    @ObservedObject var reminderStore: OMacOSReminderStore
    @ObservedObject var agentStore: OMacOSAgentUsageStore
    @ObservedObject var dictationController: OMacOSDictationController
    @ObservedObject var notificationStore: OMacOSNotificationStore
    @ObservedObject var packageStore: OMacOSPackageStore
    @ObservedObject var pluginStore: OMacOSPluginCatalogStore
    let dismissPanel: () -> Void
    @FocusState private var searchFieldFocused: Bool

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
        .focusSection()
        .onExitCommand(perform: dismissPanel)
        .onAppear {
            searchFieldFocused = panelHasSearchField
            if panelID == .media {
                state.refreshMedia()
            } else if panelID == .weather || panelID == .noticeWeather {
                if state.weatherStatus == nil {
                    state.refreshWeather()
                }
            } else if panelID == .wifiQR {
                state.refreshWiFiCredentials()
            } else if panelID == .tailscale {
                state.refreshService("tailscale")
            } else if panelID == .dropbox {
                state.refreshService("dropbox")
            } else if panelID == .packages {
                packageStore.refreshInstalledPackages()
            }
        }
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
            .keyboardShortcut(.cancelAction)
            .foregroundStyle(Color(omacosHex: colors.darkForeground))
        }
    }

    @ViewBuilder private var panelContents: some View {
        switch panelID {
        case .keybindings:
            keybindingsPanel
        case .clipboard:
            clipboardPanel
        case .emojis:
            emojiPanel
        case .capture:
            capturePanel
        case .reminders:
            remindersPanel
        case .themes:
            themesPanel
        case .wallpapers:
            wallpapersPanel
        case .defaults:
            defaultsPanel
        case .agents:
            agentsPanel
        case .weather:
            weatherPanel
        case .media:
            mediaPanel
        case .dictation:
            dictationPanel
        case .notifications:
            notificationsPanel
        case .speedtest:
            speedtestPanel(kind: "network")
        case .diskSpeedtest:
            speedtestPanel(kind: "disk")
        case .wifiQR:
            wifiQRPanel
        case .tailscale:
            tailscalePanel
        case .dropbox:
            dropboxPanel
        case .packages:
            packagesPanel
        case .plugins:
            pluginsPanel
        case .devGallery:
            developerGalleryPanel
        case .osd:
            onScreenDisplayPanel
        case .permissions:
            permissionsPanel
        case .noticeDateTime:
            dateTimeNotice
        case .noticeBattery:
            batteryNotice
        case .noticeWeather:
            weatherNotice
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
        VStack(spacing: 10) {
            searchField("Search keybindings")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredKeybindings) { binding in
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
        }
        .overlay {
            if state.keybindings.isEmpty {
                ContentUnavailableView("No keybindings found", systemImage: "keyboard")
            }
        }
    }

    private var clipboardPanel: some View {
        VStack(spacing: 10) {
            HStack {
                searchField("Search clipboard history")
                Button("Clear") { clipboardStore.clear() }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredClipboardEntries) { entry in
                        HStack(spacing: 10) {
                            Button {
                                dismissPanel()
                                clipboardStore.paste(entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.text)
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(entry.capturedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(Color(omacosHex: colors.darkForeground))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button {
                                clipboardStore.remove(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(omacosHex: colors.red))
                        }
                        .padding(11)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            .overlay {
                if clipboardStore.entries.isEmpty {
                    ContentUnavailableView("Clipboard history is empty", systemImage: "clipboard")
                }
            }
        }
    }

    private var emojiPanel: some View {
        VStack(spacing: 10) {
            HStack {
                searchField("Search common emoji")
                Button("All Emoji…") {
                    NSApp.orderFrontCharacterPalette(nil)
                }
                .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(filteredEmoji, id: \.symbol) { emoji in
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(emoji.symbol, forType: .string)
                            dismissPanel()
                        } label: {
                            VStack(spacing: 4) {
                                Text(emoji.symbol).font(.system(size: 28))
                                Text(emoji.name)
                                    .font(.system(size: 8))
                                    .lineLimit(1)
                                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                        }
                        .buttonStyle(.plain)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var capturePanel: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            captureAction("Screenshot", subtitle: "Select a region or window", systemImage: "camera.viewfinder", arguments: ["capture", "screenshot"])
            captureAction("Full Screen", subtitle: "Capture all connected displays", systemImage: "rectangle.dashed", arguments: ["capture", "screenshot", "--screen"])
            captureAction("Screen Recording", subtitle: "Record without audio", systemImage: "record.circle", arguments: ["capture", "recording"])
            captureAction("System Audio", subtitle: "Record the screen and Mac audio", systemImage: "speaker.wave.2", arguments: ["capture", "recording", "--system-audio"])
            captureAction("Microphone", subtitle: "Record the screen and microphone", systemImage: "mic", arguments: ["capture", "recording", "--microphone"])
            captureAction("All Audio", subtitle: "Record system audio and microphone", systemImage: "waveform", arguments: ["capture", "recording", "--all-audio"])
            captureAction("Stop Recording", subtitle: "Finish the current capture", systemImage: "stop.circle", arguments: ["capture", "record-stop"])
            captureAction("Extract Text", subtitle: "Recognize text on-device and copy it", systemImage: "text.viewfinder", arguments: ["capture", "text"])
            captureAction("Read QR Code", subtitle: "Recognize a QR code and copy its payload", systemImage: "qrcode.viewfinder", arguments: ["capture", "qr"])
            captureAction("Color Meter", subtitle: "Open the native macOS color inspector", systemImage: "eyedropper", arguments: ["capture", "color"])
        }
    }

    private var remindersPanel: some View {
        VStack(spacing: 10) {
            TextField(
                "What should OMacOS remind you about?",
                text: Binding(
                    get: { reminderStore.draftText },
                    set: { reminderStore.draftText = $0 }
                )
            )
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color(omacosHex: colors.lighterBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { reminderStore.draftDate },
                        set: { reminderStore.draftDate = $0 }
                    ),
                    in: Date()...
                )
                .datePickerStyle(.compact)
                Spacer()
                Button("Add") { reminderStore.addDraft() }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                    .disabled(reminderStore.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(reminderStore.reminders) { reminder in
                        HStack(spacing: 10) {
                            Image(systemName: reminder.delivered ? "checkmark.circle" : "bell")
                                .foregroundStyle(Color(omacosHex: reminder.delivered ? colors.green : colors.accent))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.text).lineLimit(2)
                                Text(reminder.dueAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                            }
                            Spacer()
                            Button {
                                reminderStore.remove(id: reminder.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(omacosHex: colors.red))
                        }
                        .padding(10)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var themesPanel: some View {
        VStack(spacing: 10) {
            searchField("Search 22 semantic themes")
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(filteredThemes, id: \.slug) { availableTheme in
                        Button {
                            state.applyTheme(availableTheme)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(omacosHex: availableTheme.colors.accent))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        Circle().stroke(Color(omacosHex: availableTheme.colors.foreground), lineWidth: 1)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(availableTheme.name).fontWeight(.semibold)
                                    Text(availableTheme.mode.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(Color(omacosHex: colors.darkForeground))
                                }
                                Spacer()
                            }
                            .padding(10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            if !state.lastActionMessage.isEmpty {
                Text(state.lastActionMessage)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
        }
    }

    private var wallpapersPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard(
                "Use your own image",
                detail: "OMacOS applies it through the public macOS desktop-image API.",
                systemImage: "photo.on.rectangle"
            )
            panelAction("Choose Wallpaper", subtitle: "PNG, JPEG, HEIC, WebP, or TIFF", systemImage: "folder") {
                state.chooseWallpaper()
            }
            if !state.lastActionMessage.isEmpty {
                Text(state.lastActionMessage)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
        }
    }

    private var defaultsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                defaultChoices(
                    title: "Terminal",
                    selected: state.defaultTerminal,
                    choices: [("ghostty", "Ghostty"), ("terminal", "Terminal"), ("iterm2", "iTerm2")]
                ) { state.setApplicationDefault(category: "terminal", value: $0) }
                defaultChoices(
                    title: "Browser",
                    selected: state.defaultBrowser,
                    choices: [("system", "System"), ("safari", "Safari"), ("chrome", "Chrome"), ("brave", "Brave"), ("firefox", "Firefox"), ("helium", "Helium")]
                ) { state.setApplicationDefault(category: "browser", value: $0) }
                defaultChoices(
                    title: "Editor",
                    selected: state.defaultEditor,
                    choices: [("nvim", "Neovim"), ("vscode", "VS Code"), ("cursor", "Cursor"), ("zed", "Zed"), ("sublime", "Sublime")]
                ) { state.setApplicationDefault(category: "editor", value: $0) }
                if !state.lastActionMessage.isEmpty {
                    Text(state.lastActionMessage)
                        .font(.caption)
                        .foregroundStyle(Color(omacosHex: colors.darkForeground))
                }
            }
        }
    }

    private var agentsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if agentStore.records.isEmpty {
                ContentUnavailableView(
                    "No agent usage yet",
                    systemImage: "brain.head.profile",
                    description: Text("Run `omacos agent usage-update` after signing in to Codex, Claude, or Fireworks.")
                )
            } else {
                HStack(spacing: 8) {
                    ForEach(agentStore.records) { record in
                        Button {
                            agentStore.selectedAgentID = record.id
                        } label: {
                            Text(record.name)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(omacosHex: record.id == agentStore.selectedRecord?.id ? colors.background : colors.foreground))
                        .background(Color(omacosHex: record.id == agentStore.selectedRecord?.id ? colors.accent : colors.lighterBackground))
                        .clipShape(Capsule())
                    }
                    Spacer()
                    Button("Refresh") { agentStore.refresh() }
                        .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                }

                if let record = agentStore.selectedRecord {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.name).font(.title2.bold())
                                    Text(record.usageStatusText?.isEmpty == false ? record.usageStatusText! : (record.tierLabel ?? "Subscription"))
                                        .foregroundStyle(Color(omacosHex: colors.darkForeground))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatTokenCount(record.todayTotalTokens ?? 0)).font(.title3.bold())
                                    Text("tokens today").font(.caption).foregroundStyle(Color(omacosHex: colors.darkForeground))
                                }
                            }

                            ForEach(record.limits ?? []) { limit in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(limit.displayTitle).fontWeight(.semibold)
                                        Spacer()
                                        Text("\(Int((limit.percent ?? 0) * 100))%")
                                    }
                                    ProgressView(value: min(max(limit.percent ?? 0, 0), 1))
                                        .tint(Color(omacosHex: (limit.percent ?? 0) >= 0.9 ? colors.red : colors.accent))
                                }
                            }

                            if let balance = record.balance, let remaining = balance.remaining {
                                statusCard(
                                    String(format: "%@%.2f remaining", currencyPrefix(balance.currency), remaining),
                                    detail: balance.estimated == true ? "Estimated prepaid balance" : "Prepaid balance",
                                    systemImage: "creditcard"
                                )
                            }

                            agentUsageDays(record.recentDays ?? [])
                            agentModelUsage(record.modelUsage ?? [:])
                        }
                    }
                }
            }

            if !agentStore.refreshMessage.isEmpty {
                Text(agentStore.refreshMessage)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
        }
    }

    private func agentUsageDays(_ days: [OMacOSAgentUsageDay]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Tokens by day").font(.caption.weight(.bold)).foregroundStyle(Color(omacosHex: colors.darkForeground))
            let maximum = max(days.map { $0.messageCount ?? 0 }.max() ?? 1, 1)
            ForEach(days) { day in
                HStack(spacing: 8) {
                    Text(day.date.suffix(5)).font(.system(size: 10, design: .monospaced)).frame(width: 40, alignment: .leading)
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(omacosHex: colors.accent))
                            .frame(width: geometry.size.width * CGFloat(day.messageCount ?? 0) / CGFloat(maximum))
                    }
                    .frame(height: 8)
                    Text(formatTokenCount(day.messageCount ?? 0)).font(.system(size: 10, design: .monospaced)).frame(width: 54, alignment: .trailing)
                }
            }
        }
    }

    private func agentModelUsage(_ models: [String: OMacOSAgentModelUsage]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Tokens by model").font(.caption.weight(.bold)).foregroundStyle(Color(omacosHex: colors.darkForeground))
            ForEach(models.sorted { $0.value.totalTokens > $1.value.totalTokens }.prefix(5), id: \.key) { model, usage in
                HStack {
                    Text(model).lineLimit(1)
                    Spacer()
                    Text(formatTokenCount(usage.totalTokens)).font(.system(size: 10, design: .monospaced))
                }
            }
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return String(count)
    }

    private func currencyPrefix(_ currency: String?) -> String {
        switch currency?.uppercased() {
        case "EUR": "€"
        case "GBP": "£"
        case "USD", nil: "$"
        default: (currency ?? "") + " "
        }
    }

    private func defaultChoices(
        title: String,
        selected: String,
        choices: [(value: String, label: String)],
        select: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(omacosHex: colors.darkForeground))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(choices, id: \.value) { choice in
                    Button {
                        select(choice.value)
                    } label: {
                        HStack {
                            Image(systemName: selected == choice.value ? "checkmark.circle.fill" : "circle")
                            Text(choice.label)
                            Spacer()
                        }
                        .padding(9)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(omacosHex: selected == choice.value ? colors.accent : colors.foreground))
                    .background(Color(omacosHex: colors.lighterBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func captureAction(_ title: String, subtitle: String, systemImage: String, arguments: [String]) -> some View {
        panelAction(title, subtitle: subtitle, systemImage: systemImage) {
            dismissPanel()
            let homeDirectory = ProcessInfo.processInfo.environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
            _ = OMacOSCommandRunner.run(
                executable: "/usr/bin/env",
                arguments: [homeDirectory + "/.local/bin/omacos"] + arguments
            )
        }
    }

    private var systemPanel: some View {
        VStack(spacing: 10) {
            panelAction("Lock", subtitle: "Show the macOS login window", systemImage: "lock") { state.lockMac() }
            panelAction("Sleep", subtitle: "Put this Mac to sleep", systemImage: "moon.zzz") { state.sleepMac() }
            panelAction("Screensaver", subtitle: "Start the configured macOS screensaver", systemImage: "sparkles.tv") { state.runSystemAction("screensaver") }
            panelAction(
                state.stayAwakeEnabled ? "Disable Stay Awake" : "Stay Awake",
                subtitle: "Prevent idle sleep and display dimming",
                systemImage: "cup.and.saucer"
            ) { state.toggleMode("stay-awake") }
            panelAction("System Settings", subtitle: "Open macOS settings", systemImage: "gearshape") { state.openSystemSettings() }
        }
    }

    private var weatherPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weather = state.weatherStatus {
                HStack(alignment: .center) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(omacosHex: colors.accent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weather.temperatureC)°C").font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(weather.description).fontWeight(.semibold)
                        Text([weather.location, weather.region].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Color(omacosHex: colors.darkForeground))
                    }
                    Spacer()
                    Button("Refresh") { state.refreshWeather() }
                        .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                }
                HStack {
                    Text("Feels like \(weather.feelsLikeC)°")
                    Spacer()
                    Text("Humidity \(weather.humidity)%")
                    Spacer()
                    Text("Wind \(weather.windKmph) km/h")
                }
                .font(.caption)
                .foregroundStyle(Color(omacosHex: colors.darkForeground))
                ForEach(weather.forecast) { day in
                    HStack {
                        Text(day.date).font(.system(size: 11, design: .monospaced)).frame(width: 84, alignment: .leading)
                        Text(day.description).lineLimit(1)
                        Spacer()
                        Text("\(day.minimumC)° / \(day.maximumC)°").font(.system(size: 11, design: .monospaced))
                    }
                    .padding(9)
                    .background(Color(omacosHex: colors.lighterBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ContentUnavailableView("Weather unavailable", systemImage: "cloud.sun", description: Text(state.weatherMessage))
                Button("Refresh forecast") { state.refreshWeather() }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var mediaPanel: some View {
        VStack(spacing: 18) {
            if let media = state.mediaStatus, media.hasTrack {
                Image(systemName: "music.note")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Color(omacosHex: colors.accent))
                VStack(spacing: 4) {
                    Text(media.title).font(.title3.bold()).lineLimit(2)
                    Text(media.artist).foregroundStyle(Color(omacosHex: colors.darkForeground)).lineLimit(1)
                    Text(media.application).font(.caption2).foregroundStyle(Color(omacosHex: colors.darkForeground))
                }
                HStack(spacing: 24) {
                    Button { state.controlMedia("previous") } label: { Image(systemName: "backward.fill") }
                    Button { state.controlMedia("play-pause") } label: {
                        Image(systemName: media.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 34))
                    }
                    Button { state.controlMedia("next") } label: { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
            } else {
                ContentUnavailableView("Nothing playing", systemImage: "music.note", description: Text("Start playback in Apple Music or Spotify, then refresh."))
            }
            Button("Refresh") { state.refreshMedia() }
                .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
        }
        .frame(maxWidth: .infinity)
    }

    private var dictationPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: dictationController.isRecording ? "waveform.and.mic" : "mic")
                .font(.system(size: 48))
                .foregroundStyle(Color(omacosHex: dictationController.isRecording ? colors.red : colors.accent))
            Text(dictationController.statusMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(omacosHex: colors.darkForeground))
            if !dictationController.transcript.isEmpty {
                Text(dictationController.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(Color(omacosHex: colors.lighterBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button(dictationController.isRecording ? "Stop and Insert" : "Start Dictation") {
                dictationController.toggle()
            }
            .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
        }
        .frame(maxWidth: .infinity)
    }

    private var notificationsPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("OMacOS reminders and service notices")
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                Spacer()
                Button("Clear") { notificationStore.clear() }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(notificationStore.records) { record in
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: record.source == "reminder" ? "bell" : "info.circle")
                                .foregroundStyle(Color(omacosHex: colors.accent))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.title).fontWeight(.semibold)
                                Text(record.body).lineLimit(4)
                                Text(record.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                            }
                            Spacer()
                        }
                        .padding(11)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .overlay {
                if notificationStore.records.isEmpty {
                    ContentUnavailableView("No OMacOS notifications", systemImage: "bell")
                }
            }
            Text("macOS does not expose other applications’ Notification Center history to third-party apps.")
                .font(.caption2)
                .foregroundStyle(Color(omacosHex: colors.darkForeground))
        }
    }

    private func speedtestPanel(kind: String) -> some View {
        let isNetwork = kind == "network"
        let summary = isNetwork ? state.networkSpeedSummary : state.diskSpeedSummary
        return VStack(spacing: 18) {
            Image(systemName: isNetwork ? "gauge.with.dots.needle.67percent" : "internaldrive")
                .font(.system(size: 54))
                .foregroundStyle(Color(omacosHex: colors.accent))
            Text(summary)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            if state.speedTestRunning {
                ProgressView().controlSize(.small)
                Text(isNetwork ? "Measuring network quality…" : "Writing and reading a temporary 64 MB file…")
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            } else {
                Button("Run \(isNetwork ? "Network" : "Disk") Test") { state.runSpeedTest(kind) }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var wifiQRPanel: some View {
        VStack(spacing: 12) {
            if let credentials = state.wifiCredentials,
               let qrImage = qrCodeImage(for: credentials.payload) {
                qrImage
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 210, height: 210)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(credentials.ssid).font(.title3.bold())
                Text(state.wifiCredentialMessage)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                Button("Copy Password") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(credentials.password, forType: .string)
                }
                .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            } else {
                ProgressView().controlSize(.small)
                Text(state.wifiCredentialMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                Button("Try Again") { state.refreshWiFiCredentials() }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func qrCodeImage(for payload: String) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else {
            return nil
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return Image(decorative: cgImage, scale: 1)
    }

    private var tailscalePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let service = state.tailscaleStatus, service.installed {
                HStack {
                    statusCard(
                        service.online ? "Connected" : "Disconnected",
                        detail: service.tailnet.isEmpty ? "Tailscale" : service.tailnet,
                        systemImage: "network.badge.shield.half.filled"
                    )
                    Button(service.online ? "Disconnect" : "Connect") {
                        state.controlService("tailscale", action: service.online ? "down" : "up")
                    }
                    .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                }
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(service.machines) { machine in
                            HStack {
                                Circle()
                                    .fill(Color(omacosHex: machine.online ? colors.green : colors.darkForeground))
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(machine.name).fontWeight(.semibold)
                                    Text(machine.ip).font(.caption2).foregroundStyle(Color(omacosHex: colors.darkForeground))
                                }
                                Spacer()
                                Button("Copy IP") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(machine.ip, forType: .string)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color(omacosHex: colors.accent))
                            }
                            .padding(9)
                            .background(Color(omacosHex: colors.lighterBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            } else {
                ContentUnavailableView("Tailscale is not installed", systemImage: "network.badge.shield.half.filled")
                Button("Open Tailscale Download") {
                    NSWorkspace.shared.open(URL(string: "https://tailscale.com/download/mac")!)
                }
                .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var dropboxPanel: some View {
        VStack(spacing: 12) {
            if let service = state.dropboxStatus, service.installed {
                statusCard(
                    service.running ? "Dropbox is running" : "Dropbox is not running",
                    detail: String(format: "%.1f GB in the local sync folder", Double(service.storageKB) / 1_048_576),
                    systemImage: "shippingbox"
                )
                panelAction("Open Dropbox Folder", subtitle: service.path, systemImage: "folder") {
                    state.controlService("dropbox", action: "folder")
                }
                panelAction("Open Dropbox", subtitle: "Launch the desktop client", systemImage: "shippingbox") {
                    state.controlService("dropbox", action: "open")
                }
            } else {
                ContentUnavailableView("Dropbox is not installed", systemImage: "shippingbox")
                Button("Open Dropbox Download") {
                    NSWorkspace.shared.open(URL(string: "https://www.dropbox.com/install")!)
                }
                .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
            }
        }
    }

    private var packagesPanel: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(packageStore.categories, id: \.self) { category in
                        Button {
                            packageStore.selectedCategory = category
                        } label: {
                            Text(category.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(omacosHex: packageStore.selectedCategory == category ? colors.background : colors.foreground))
                        .background(Color(omacosHex: packageStore.selectedCategory == category ? colors.accent : colors.lighterBackground))
                        .clipShape(Capsule())
                    }
                }
            }
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(filteredOptionalPackages) { package in
                        HStack(spacing: 11) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(package.name).fontWeight(.semibold)
                                Text(package.description)
                                    .font(.caption)
                                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                            }
                            Spacer()
                            if packageStore.workingPackageID == package.id {
                                ProgressView().controlSize(.small)
                            } else {
                                Button(packageStore.installedPackageIDs.contains(package.id) ? "Remove" : "Install") {
                                    packageStore.toggleInstallation(package)
                                }
                                .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                            }
                        }
                        .padding(10)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            if !packageStore.statusMessage.isEmpty {
                Text(packageStore.statusMessage)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
            Text("Each app is installed directly by Homebrew only after you select Install. Third-party licenses and permissions remain separate.")
                .font(.caption2)
                .foregroundStyle(Color(omacosHex: colors.darkForeground))
        }
    }

    private var pluginsPanel: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(pluginStore.grades, id: \.self) { grade in
                        Button {
                            pluginStore.selectedGrade = grade
                        } label: {
                            Text(grade.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(omacosHex: pluginStore.selectedGrade == grade ? colors.background : colors.foreground))
                        .background(Color(omacosHex: pluginStore.selectedGrade == grade ? colors.accent : colors.lighterBackground))
                        .clipShape(Capsule())
                    }
                }
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredPluginRecords) { plugin in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(plugin.name).fontWeight(.semibold)
                                Spacer()
                                Text(plugin.grade.replacingOccurrences(of: "-", with: " ").uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(omacosHex: pluginGradeColor(plugin.grade)))
                            }
                            Text(plugin.implementation)
                            Text(plugin.limitation)
                                .font(.caption)
                                .foregroundStyle(Color(omacosHex: colors.darkForeground))
                        }
                        .padding(11)
                        .background(Color(omacosHex: colors.lighterBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Text("Third-party providers run out of process. See docs/plugin-provider.md for the versioned JSON contract.")
                .font(.caption2)
                .foregroundStyle(Color(omacosHex: colors.darkForeground))
        }
    }

    private var developerGalleryPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Typography")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                Text("Quattro display heading")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Native SwiftUI components share the active semantic theme.")
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))

                Text("Semantic palette")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach([
                        ("Accent", colors.accent), ("Red", colors.red),
                        ("Green", colors.green), ("Yellow", colors.yellow),
                        ("Blue", colors.blue), ("Magenta", colors.magenta),
                        ("Cyan", colors.cyan), ("Text", colors.foreground)
                    ], id: \.0) { name, color in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(omacosHex: color))
                                .frame(height: 38)
                            Text(name).font(.caption2)
                        }
                    }
                }

                statusCard("Status card", detail: "Reusable shell component", systemImage: "checkmark.circle")
                ProgressView(value: 0.68)
                    .tint(Color(omacosHex: colors.accent))
                HStack {
                    Button("Primary") {}
                        .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
                    Button("Secondary") {}
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private var onScreenDisplayPanel: some View {
        VStack(spacing: 18) {
            Image(systemName: state.outputMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color(omacosHex: colors.accent))
            Text(state.outputMuted ? "Muted" : "Volume \(state.volumePercentage)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            ProgressView(value: Double(state.volumePercentage), total: 100)
                .tint(Color(omacosHex: colors.accent))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionsPanel: some View {
        let permissionStatus = OMacOSPermissionStatus.current()
        return ScrollView {
            VStack(spacing: 9) {
                permissionRow("Accessibility", status: permissionStatus.accessibility, settingsName: "accessibility")
                permissionRow("Screen Recording", status: permissionStatus.screenRecording, settingsName: "screen-recording")
                permissionRow("Input Monitoring", status: permissionStatus.inputMonitoring, settingsName: "input-monitoring")
                permissionRow("Microphone", status: permissionStatus.microphone, settingsName: "microphone")
                permissionRow("Camera", status: permissionStatus.camera, settingsName: "camera")
                permissionRow("Speech Recognition", status: permissionStatus.speechRecognition, settingsName: "speech-recognition")
                Text("Karabiner-Elements has a separate Input Monitoring identity. OMacOS never grants permissions on your behalf.")
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
        }
    }

    private func permissionRow(_ title: String, status: String, settingsName: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: status == "granted" ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(Color(omacosHex: status == "granted" ? colors.green : colors.yellow))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(status.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: colors.darkForeground))
            }
            Spacer()
            Button("Open Settings") {
                let homeDirectory = ProcessInfo.processInfo.environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
                _ = OMacOSCommandRunner.run(
                    executable: "/usr/bin/env",
                    arguments: [homeDirectory + "/.local/bin/omacos", "permissions", "open", settingsName]
                )
            }
            .buttonStyle(OMacOSPanelButtonStyle(theme: theme))
        }
        .padding(10)
        .background(Color(omacosHex: colors.lighterBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func pluginGradeColor(_ grade: String) -> String {
        switch grade {
        case "exact": colors.green
        case "close", "native-replacement": colors.accent
        case "partial": colors.yellow
        default: colors.darkForeground
        }
    }

    private var dateTimeNotice: some View {
        VStack(spacing: 8) {
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(.title3.weight(.semibold))
            Text(Date(), format: .dateTime.hour().minute().second())
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Color(omacosHex: colors.accent))
        }
        .frame(maxWidth: .infinity)
    }

    private var batteryNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "battery.75percent").font(.system(size: 42)).foregroundStyle(Color(omacosHex: colors.accent))
            Text(state.batteryPercentage).font(.system(size: 38, weight: .bold, design: .rounded))
            Text(state.batterySource).foregroundStyle(Color(omacosHex: colors.darkForeground))
        }
        .frame(maxWidth: .infinity)
    }

    private var weatherNotice: some View {
        VStack(spacing: 9) {
            if let weather = state.weatherStatus {
                Image(systemName: "cloud.sun.fill").font(.system(size: 42)).foregroundStyle(Color(omacosHex: colors.accent))
                Text("\(weather.temperatureC)°C").font(.system(size: 38, weight: .bold, design: .rounded))
                Text(weather.description).fontWeight(.semibold)
                Text(weather.location).foregroundStyle(Color(omacosHex: colors.darkForeground))
            } else {
                ContentUnavailableView("Weather unavailable", systemImage: "cloud.sun")
            }
        }
        .frame(maxWidth: .infinity)
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
        switch panelID {
        case .keybindings, .clipboard, .emojis, .themes, .agents, .notifications, .packages, .plugins, .devGallery: 620
        default: 430
        }
    }

    private var panelHeight: CGFloat {
        switch panelID {
        case .keybindings, .clipboard, .emojis, .themes, .agents, .notifications, .packages, .plugins, .devGallery: 620
        case .clock: 520
        case .system: 430
        case .weather: 440
        case .wifiQR: 440
        case .noticeDateTime, .noticeBattery, .noticeWeather, .osd: 280
        default: 360
        }
    }

    private func searchField(_ prompt: String) -> some View {
        TextField(
            prompt,
            text: Binding(
                get: { state.panelSearchText },
                set: { state.panelSearchText = $0 }
            )
        )
            .textFieldStyle(.plain)
            .focused($searchFieldFocused)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color(omacosHex: colors.lighterBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var panelHasSearchField: Bool {
        switch panelID {
        case .keybindings, .clipboard, .emojis, .themes:
            true
        default:
            false
        }
    }

    private var filteredKeybindings: [OMacOSKeybinding] {
        guard !state.panelSearchText.isEmpty else { return state.keybindings }
        return state.keybindings.filter {
            $0.description.localizedCaseInsensitiveContains(state.panelSearchText)
                || $0.displayChord.localizedCaseInsensitiveContains(state.panelSearchText)
        }
    }

    private var filteredClipboardEntries: [OMacOSClipboardEntry] {
        guard !state.panelSearchText.isEmpty else { return clipboardStore.entries }
        return clipboardStore.entries.filter { $0.text.localizedCaseInsensitiveContains(state.panelSearchText) }
    }

    private var filteredEmoji: [(symbol: String, name: String)] {
        let emoji: [(symbol: String, name: String)] = [
            ("😀", "grinning"), ("😃", "happy"), ("😄", "smile"), ("😁", "grin"),
            ("😂", "joy"), ("🤣", "laughing"), ("😊", "blush"), ("😍", "heart eyes"),
            ("🥰", "love"), ("😎", "cool"), ("🤔", "thinking"), ("🫡", "salute"),
            ("😴", "sleep"), ("😭", "cry"), ("😡", "angry"), ("🤯", "mind blown"),
            ("👍", "thumbs up"), ("👎", "thumbs down"), ("👏", "clap"), ("🙏", "please"),
            ("💪", "strong"), ("🤝", "handshake"), ("👀", "eyes"), ("🧠", "brain"),
            ("❤️", "heart"), ("💔", "broken heart"), ("🔥", "fire"), ("✨", "sparkles"),
            ("🎉", "party"), ("🚀", "rocket"), ("✅", "check"), ("❌", "cross"),
            ("⚠️", "warning"), ("💡", "idea"), ("📌", "pin"), ("🔗", "link"),
            ("🐛", "bug"), ("🛠️", "tools"), ("💻", "computer"), ("🍎", "apple")
        ]
        guard !state.panelSearchText.isEmpty else { return emoji }
        return emoji.filter { $0.name.localizedCaseInsensitiveContains(state.panelSearchText) }
    }

    private var filteredThemes: [OMacOSTheme] {
        guard !state.panelSearchText.isEmpty else { return state.availableThemes }
        return state.availableThemes.filter {
            $0.name.localizedCaseInsensitiveContains(state.panelSearchText)
                || $0.mode.localizedCaseInsensitiveContains(state.panelSearchText)
        }
    }

    private var filteredOptionalPackages: [OMacOSOptionalPackage] {
        guard packageStore.selectedCategory != "all" else { return packageStore.packages }
        return packageStore.packages.filter { $0.category == packageStore.selectedCategory }
    }

    private var filteredPluginRecords: [OMacOSPluginParityRecord] {
        guard pluginStore.selectedGrade != "all" else { return pluginStore.plugins }
        return pluginStore.plugins.filter { $0.grade == pluginStore.selectedGrade }
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
