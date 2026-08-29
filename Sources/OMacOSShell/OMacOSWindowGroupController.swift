import ApplicationServices
import Foundation

private struct OMacOSWindowGroup {
    var windows: [AXUIElement]
    var activeIndex: Int
}

@MainActor
final class OMacOSWindowGroupController {
    private var groups: [OMacOSWindowGroup] = []

    func perform(_ action: String, value: String?) {
        switch action {
        case "toggle": toggleFocusedWindowGroup()
        case "out": removeFocusedWindowFromGroup()
        case "join": joinFocusedWindow(direction: value ?? "right")
        case "next": cycleFocusedGroup(by: 1)
        case "previous": cycleFocusedGroup(by: -1)
        case "index":
            if let value, let index = Int(value) {
                focusWindow(at: index - 1)
            }
        default: break
        }
    }

    private func toggleFocusedWindowGroup() {
        guard let focusedWindow = try? OMacOSWindowActions.focusedWindowElement() else { return }
        if let groupIndex = groupIndex(containing: focusedWindow) {
            groups.remove(at: groupIndex)
        } else {
            groups.append(OMacOSWindowGroup(windows: [focusedWindow], activeIndex: 0))
        }
    }

    private func joinFocusedWindow(direction: String) {
        guard let focusedWindow = try? OMacOSWindowActions.focusedWindowElement(),
              let focusedFrame = try? OMacOSWindowActions.windowFrame(focusedWindow),
              let targetWindow = nearestWindow(to: focusedWindow, frame: focusedFrame, direction: direction) else {
            return
        }

        let focusedGroupIndex = groupIndex(containing: focusedWindow)
        let targetGroupIndex = groupIndex(containing: targetWindow)
        var groupedWindows: [AXUIElement] = []
        for window in [focusedWindow, targetWindow] {
            appendUnique(window, to: &groupedWindows)
        }
        if let focusedGroupIndex {
            for window in groups[focusedGroupIndex].windows { appendUnique(window, to: &groupedWindows) }
        }
        if let targetGroupIndex {
            for window in groups[targetGroupIndex].windows { appendUnique(window, to: &groupedWindows) }
        }

        let indicesToRemove = [focusedGroupIndex, targetGroupIndex]
            .compactMap { $0 }
            .uniqued()
            .sorted(by: >)
        for index in indicesToRemove { groups.remove(at: index) }
        for window in groupedWindows {
            try? OMacOSWindowActions.setWindowFrame(focusedFrame, window: window)
        }
        let activeIndex = groupedWindows.firstIndex { sameWindow($0, focusedWindow) } ?? 0
        groups.append(OMacOSWindowGroup(windows: groupedWindows, activeIndex: activeIndex))
        OMacOSWindowActions.raiseWindow(focusedWindow)
    }

    private func removeFocusedWindowFromGroup() {
        guard let focusedWindow = try? OMacOSWindowActions.focusedWindowElement(),
              let groupIndex = groupIndex(containing: focusedWindow) else { return }
        groups[groupIndex].windows.removeAll { sameWindow($0, focusedWindow) }
        if groups[groupIndex].windows.count < 2 {
            groups.remove(at: groupIndex)
        }
        if var frame = try? OMacOSWindowActions.windowFrame(focusedWindow) {
            frame.origin.x += 28
            frame.origin.y += 28
            try? OMacOSWindowActions.setWindowFrame(frame, window: focusedWindow)
        }
        OMacOSWindowActions.raiseWindow(focusedWindow)
    }

    private func cycleFocusedGroup(by offset: Int) {
        guard let focusedWindow = try? OMacOSWindowActions.focusedWindowElement(),
              let groupIndex = groupIndex(containing: focusedWindow),
              !groups[groupIndex].windows.isEmpty else { return }
        let count = groups[groupIndex].windows.count
        groups[groupIndex].activeIndex = (groups[groupIndex].activeIndex + offset + count) % count
        OMacOSWindowActions.raiseWindow(groups[groupIndex].windows[groups[groupIndex].activeIndex])
    }

    private func focusWindow(at requestedIndex: Int) {
        guard let focusedWindow = try? OMacOSWindowActions.focusedWindowElement(),
              let groupIndex = groupIndex(containing: focusedWindow),
              groups[groupIndex].windows.indices.contains(requestedIndex) else { return }
        groups[groupIndex].activeIndex = requestedIndex
        OMacOSWindowActions.raiseWindow(groups[groupIndex].windows[requestedIndex])
    }

    private func nearestWindow(
        to focusedWindow: AXUIElement,
        frame focusedFrame: CGRect,
        direction: String
    ) -> AXUIElement? {
        let candidates = (try? OMacOSWindowActions.visibleWindowElements()) ?? []
        return candidates
            .filter { !sameWindow($0, focusedWindow) }
            .compactMap { window -> (AXUIElement, CGFloat)? in
                guard let frame = try? OMacOSWindowActions.windowFrame(window) else { return nil }
                let deltaX = frame.midX - focusedFrame.midX
                let deltaY = frame.midY - focusedFrame.midY
                let isInDirection = switch direction {
                case "left": deltaX < 0
                case "right": deltaX > 0
                case "up": deltaY < 0
                case "down": deltaY > 0
                default: false
                }
                guard isInDirection else { return nil }
                return (window, hypot(deltaX, deltaY))
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func groupIndex(containing window: AXUIElement) -> Int? {
        groups.firstIndex { group in group.windows.contains { sameWindow($0, window) } }
    }

    private func appendUnique(_ window: AXUIElement, to windows: inout [AXUIElement]) {
        if !windows.contains(where: { sameWindow($0, window) }) {
            windows.append(window)
        }
    }

    private func sameWindow(_ left: AXUIElement, _ right: AXUIElement) -> Bool {
        CFEqual(left, right)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
