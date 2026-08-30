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

    init(theme: OMacOSTheme, initialMenuID: String? = nil, dismissMenu: @escaping () -> Void) {
        self.theme = theme
        self.dismissMenu = dismissMenu
        _store = StateObject(wrappedValue: OMacOSMenuStore(initialMenuID: initialMenuID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            menuHeader
            Divider().overlay(Color(omacosHex: theme.colors.selection))
            searchField
            menuEntries
            if !store.actionMessage.isEmpty {
                Text(store.actionMessage)
                    .font(.caption)
                    .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
                    .lineLimit(3)
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
        .focusSection()
        .onAppear(perform: focusInitialMenuEntry)
        .onChange(of: store.visibleEntries.map(\.id)) { _, entryIDs in
            synchronizeSelection(with: entryIDs)
        }
        .onMoveCommand(perform: handleMoveCommand)
        .onExitCommand(perform: handleEscapeCommand)
    }

    private var menuHeader: some View {
        HStack(spacing: 10) {
            if store.currentMenuID != nil {
                Button { store.navigateBack() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("OMacOS")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(store.currentTitle)
                    .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
            }
            Spacer()
            Text("Right Option + Space")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
            TextField("Search OMacOS actions", text: $store.searchText)
                .textFieldStyle(.plain)
                .focused($focusedTarget, equals: .search)
                .onSubmit(activateSelectedEntry)
            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(omacosHex: theme.colors.lighterBackground))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var menuEntries: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(store.visibleEntries) { entry in
                        menuButton(for: entry)
                            .id(entry.id)
                    }
                }
            }
            .onChange(of: keyboardState.selectedEntryID) { _, selectedEntryID in
                if let selectedEntryID {
                    withAnimation(.easeOut(duration: 0.08)) {
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
            HStack(spacing: 12) {
                Image(systemName: icon(for: entry.id))
                    .frame(width: 24)
                    .foregroundStyle(Color(omacosHex: theme.colors.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label).fontWeight(.semibold)
                }
                Spacer()
                if store.actionRunning && !hasChildren {
                    ProgressView().controlSize(.small)
                } else if hasChildren {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedTarget, equals: .entry(entry.id))
        .background(
            Color(omacosHex: keyboardState.selectedEntryID == entry.id
                ? theme.colors.selection
                : theme.colors.lighterBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
            if keyboardState.selectedEntryID == entry.id {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(omacosHex: theme.colors.accent), lineWidth: 1)
            }
        }
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
