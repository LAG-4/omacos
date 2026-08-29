import SwiftUI

struct OMacOSCommandMenuView: View {
    let theme: OMacOSTheme
    let dismissMenu: () -> Void
    let openPanel: (OMacOSPanelID) -> Void

    @StateObject private var store = OMacOSMenuStore()

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
            TextField("Search all Quattro actions", text: $store.searchText)
                .textFieldStyle(.plain)
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
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach(store.visibleEntries) { entry in
                    menuButton(for: entry)
                }
            }
        }
    }

    private func menuButton(for entry: OMacOSMenuEntry) -> some View {
        let hasChildren = store.hasChildren(entry)
        return Button {
            if hasChildren {
                store.open(entry)
            } else {
                Task {
                    if await store.execute(entry) {
                        dismissMenu()
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon(for: entry.id))
                    .frame(width: 24)
                    .foregroundStyle(Color(omacosHex: theme.colors.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label).fontWeight(.semibold)
                    if !store.searchText.isEmpty {
                        Text(entry.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color(omacosHex: theme.colors.darkForeground))
                    }
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
        .background(Color(omacosHex: theme.colors.lighterBackground))
        .clipShape(RoundedRectangle(cornerRadius: 9))
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
