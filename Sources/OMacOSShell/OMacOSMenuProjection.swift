import Foundation

/// Converts the frozen Omarchy reference menu into the macOS product menu shown to users.
struct OMacOSMenuProjection: Decodable {
    let schemaVersion: Int
    let hiddenEntryRoots: [String]
    let replacementLabels: [String: String]

    /// Removes Linux-only menu branches and applies macOS outcome names without changing command identifiers.
    func apply(to inventoryEntries: [OMacOSMenuEntry]) -> [OMacOSMenuEntry] {
        inventoryEntries.compactMap { entry in
            guard !isHidden(entry.id) else { return nil }
            return OMacOSMenuEntry(
                id: entry.id,
                label: replacementLabels[entry.id] ?? entry.label,
                referenceKind: entry.referenceKind
            )
        }
    }

    private func isHidden(_ entryID: String) -> Bool {
        hiddenEntryRoots.contains { root in
            entryID == root || entryID.hasPrefix(root + ".")
        }
    }
}
