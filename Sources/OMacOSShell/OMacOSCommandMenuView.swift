import SwiftUI

struct OMacOSCommandMenuView: View {
    private enum FocusTarget: Hashable {
        case search
        case entry(String)
    }

    let theme: OMacOSTheme
    let dismissMenu: () -> Void

    @StateObject private var store: OMacOSMenuStore
    @StateObject private var keyboardState = OMacOSCommandMenuKeyboardState()
    @FocusState private var focusedTarget: FocusTarget?

    private let contract = OMacOSShellContract.shared

    init(theme: OMacOSTheme, initialMenuID: String? = nil, dismissMenu: @escaping () -> Void) {
        self.theme = theme
        self.dismissMenu = dismissMenu
        _store = StateObject(wrappedValue: OMacOSMenuStore(initialMenuID: initialMenuID))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(omacosHex: theme.colors.background)
                    .opacity(contract.menu.scrimOpacity)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissMenu)

                commandCard(screenHeight: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .focusSection()
        .onAppear(perform: focusInitialMenuEntry)
        .onChange(of: store.visibleEntries.map(\.id)) { _, entryIDs in
            synchronizeSelection(with: entryIDs)
        }
        .onMoveCommand(perform: handleMoveCommand)
        .onExitCommand(perform: handleEscapeCommand)
    }

    private func commandCard(screenHeight: CGFloat) -> some View {
        let rowListHeight = visibleRowListHeight(screenHeight: screenHeight)
        return VStack(alignment: .leading, spacing: CGFloat(contract.menu.contentSpacing)) {
            menuHeader
            menuEntries
                .frame(height: rowListHeight)
            if !store.actionMessage.isEmpty {
                Text(store.actionMessage)
                    .font(quattroFont(size: contract.typography.caption))
                    .foregroundStyle(Color(omacosHex: theme.colors.foreground).opacity(0.52))
                    .lineLimit(3)
            }
        }
        .foregroundStyle(Color(omacosHex: theme.colors.foreground))
        .padding(CGFloat(contract.menu.panelPadding))
        .frame(width: CGFloat(contract.menu.width))
        .background(Color(omacosHex: theme.colors.background))
        .overlay {
            Rectangle()
                .stroke(Color(omacosHex: theme.colors.accent), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { }
    }

    private var menuHeader: some View {
        HStack(spacing: CGFloat(contract.spacing.sm)) {
            if store.currentMenuID != nil {
                Button { store.navigateBack() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            TextField(store.currentTitle + "…", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(quattroFont(size: contract.typography.heading))
                .foregroundStyle(Color(omacosHex: theme.colors.foreground))
                .focused($focusedTarget, equals: .search)
                .onSubmit(activateSelectedEntry)
                .accessibilityLabel("Filter \(store.currentTitle)")

            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(omacosHex: theme.colors.foreground).opacity(0.52))
                .accessibilityLabel("Clear search")
            }

            Button(action: dismissMenu) {
                Image(systemName: "xmark")
                    .font(quattroFont(size: contract.typography.bodySmall, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(omacosHex: theme.colors.foreground).opacity(0.58))
            .help("Close command menu")
            .accessibilityLabel("Close command menu")
        }
        .frame(height: CGFloat(contract.menu.headerHeight))
    }

    private var menuEntries: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: CGFloat(contract.menu.rowSpacing)) {
                    ForEach(store.visibleEntries) { entry in
                        menuButton(for: entry)
                            .id(entry.id)
                    }
                }
            }
            .onChange(of: keyboardState.selectedEntryID) { _, selectedEntryID in
                if let selectedEntryID {
                    withAnimation(.easeOut(duration: interactionDuration)) {
                        scrollProxy.scrollTo(selectedEntryID, anchor: .center)
                    }
                }
            }
        }
    }

    private func menuButton(for entry: OMacOSMenuEntry) -> some View {
        let hasChildren = store.hasChildren(entry)
        return Button {
            activate(entry)
        } label: {
            HStack(spacing: CGFloat(contract.spacing.md)) {
                Image(systemName: icon(for: entry.id))
                    .font(.system(size: CGFloat(contract.typography.iconLarge)))
                    .frame(width: 36)
                    .foregroundStyle(rowForeground(entryID: entry.id))
                Text(entry.label)
                    .font(quattroFont(size: contract.typography.heading, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if store.actionRunning && !hasChildren {
                    ProgressView().controlSize(.small)
                } else if hasChildren {
                    Text("›")
                        .font(quattroFont(size: contract.typography.heading))
                        .foregroundStyle(rowForeground(entryID: entry.id).opacity(0.36))
                }
            }
            .padding(.horizontal, CGFloat(contract.spacing.lg))
            .frame(height: CGFloat(contract.menu.rowHeight))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedTarget, equals: .entry(entry.id))
        .foregroundStyle(rowForeground(entryID: entry.id))
        .background(rowBackground(entryID: entry.id))
        .overlay {
            if keyboardState.selectedEntryID == entry.id {
                Rectangle()
                    .stroke(
                        Color(omacosHex: theme.colors.accent)
                            .opacity(contract.menu.selectedBorderOpacity),
                        lineWidth: 1
                    )
            }
        }
    }

    private func visibleRowListHeight(screenHeight: CGFloat) -> CGFloat {
        let count = max(store.visibleEntries.count, 1)
        let rowHeight = CGFloat(contract.menu.rowHeight)
        let rowSpacing = CGFloat(contract.menu.rowSpacing)
        let desiredHeight = CGFloat(count) * rowHeight + CGFloat(max(0, count - 1)) * rowSpacing
        let fixedHeight = CGFloat(contract.menu.panelPadding * 2 + contract.menu.headerHeight + contract.menu.contentSpacing)
        let maximumCardHeight = max(
            rowHeight + fixedHeight,
            screenHeight * contract.menu.maximumScreenHeightFraction
        )
        return min(desiredHeight, maximumCardHeight - fixedHeight)
    }

    private func rowForeground(entryID: String) -> Color {
        let color = keyboardState.selectedEntryID == entryID
            ? theme.colors.accent
            : theme.colors.foreground
        return Color(omacosHex: color)
    }

    private func rowBackground(entryID: String) -> Color {
        guard keyboardState.selectedEntryID == entryID else { return .clear }
        return Color(omacosHex: theme.colors.foreground)
            .opacity(contract.menu.selectedBackgroundOpacity)
    }

    private func quattroFont(size: Int, weight: Font.Weight = .regular) -> Font {
        .custom(contract.typography.family, size: CGFloat(size)).weight(weight)
    }

    private var interactionDuration: Double {
        Double(contract.animation.selectionColorMilliseconds) / 1_000
    }

    private func focusInitialMenuEntry() {
        keyboardState.selectedEntryID = store.visibleEntries.first?.id
        Task { @MainActor in
            await Task.yield()
            focusedTarget = .search
        }
    }

    private func synchronizeSelection(with entryIDs: [String]) {
        if let selectedEntryID = keyboardState.selectedEntryID, entryIDs.contains(selectedEntryID) {
            return
        }
        keyboardState.selectedEntryID = entryIDs.first
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        let entryIDs = store.visibleEntries.map(\.id)
        switch direction {
        case .down:
            if focusedTarget == .search {
                focusCurrentSelection(entryIDs: entryIDs)
            } else {
                moveSelection(offset: 1, entryIDs: entryIDs)
            }
        case .up:
            moveSelection(offset: -1, entryIDs: entryIDs)
        case .right:
            if let entry = selectedEntry {
                activate(entry)
            }
        case .left:
            navigateBackOrDismiss()
        default:
            break
        }
    }

    private func moveSelection(offset: Int, entryIDs: [String]) {
        keyboardState.selectedEntryID = OMacOSKeyboardSelection.movedID(
            currentID: keyboardState.selectedEntryID,
            orderedIDs: entryIDs,
            offset: offset
        )
        if let selectedEntryID = keyboardState.selectedEntryID {
            focusedTarget = .entry(selectedEntryID)
        }
    }

    private func focusCurrentSelection(entryIDs: [String]) {
        if keyboardState.selectedEntryID == nil {
            keyboardState.selectedEntryID = entryIDs.first
        }
        if let selectedEntryID = keyboardState.selectedEntryID {
            focusedTarget = .entry(selectedEntryID)
        }
    }

    private func activateSelectedEntry() {
        if let entry = selectedEntry ?? store.visibleEntries.first {
            activate(entry)
        }
    }

    private var selectedEntry: OMacOSMenuEntry? {
        guard let selectedEntryID = keyboardState.selectedEntryID else { return nil }
        return store.visibleEntries.first { $0.id == selectedEntryID }
    }

    private func activate(_ entry: OMacOSMenuEntry) {
        if store.hasChildren(entry) {
            store.open(entry)
            keyboardState.selectedEntryID = store.visibleEntries.first?.id
            if let selectedEntryID = keyboardState.selectedEntryID {
                focusedTarget = .entry(selectedEntryID)
            }
            return
        }
        Task {
            if await store.execute(entry) {
                dismissMenu()
            }
        }
    }

    private func handleEscapeCommand() {
        if !store.searchText.isEmpty {
            store.searchText = ""
            keyboardState.selectedEntryID = store.visibleEntries.first?.id
            focusedTarget = .search
        } else {
            navigateBackOrDismiss()
        }
    }

    private func navigateBackOrDismiss() {
        if store.currentMenuID == nil {
            dismissMenu()
            return
        }
        store.navigateBack()
        keyboardState.selectedEntryID = store.visibleEntries.first?.id
        if let selectedEntryID = keyboardState.selectedEntryID {
            focusedTarget = .entry(selectedEntryID)
        }
    }

    private func icon(for id: String) -> String {
        switch id.split(separator: ".").first.map(String.init) {
        case "apps": "square.grid.2x2"
        case "learn": "book"
        case "trigger": "bolt"
        case "style": "paintpalette"
        case "setup": "gearshape"
        case "install": "square.and.arrow.down"
        case "remove": "trash"
        case "update": "arrow.triangle.2.circlepath"
        case "about": "info.circle"
        case "system": "power"
        default: "command"
        }
    }
}
