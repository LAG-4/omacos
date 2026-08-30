import Combine
import Foundation

@MainActor
final class OMacOSCommandMenuKeyboardState: ObservableObject {
    @Published var selectedEntryID: String?
}

enum OMacOSKeyboardSelection {
    /// Moves a keyboard selection through ordered control IDs and wraps at either end.
    static func movedID(
        currentID: String?,
        orderedIDs: [String],
        offset: Int
    ) -> String? {
        guard !orderedIDs.isEmpty, offset != 0 else { return currentID ?? orderedIDs.first }
        guard let currentID,
              let currentIndex = orderedIDs.firstIndex(of: currentID) else {
            return offset > 0 ? orderedIDs.first : orderedIDs.last
        }
        let count = orderedIDs.count
        let nextIndex = (currentIndex + offset % count + count) % count
        return orderedIDs[nextIndex]
    }
}
