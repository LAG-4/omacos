import ApplicationServices
import Foundation

private enum OMacOSPointerGesture {
    case move
    case resize
}

final class OMacOSPointerGestureController {
    private var superKeyDown = false
    private var activeGesture: OMacOSPointerGesture?
    private var activeWindow: AXUIElement?
    private var initialPointer = CGPoint.zero
    private var initialFrame = CGRect.zero
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastWorkspaceScroll = Date.distantPast

    func start() {
        guard eventTap == nil else { return }
        let eventTypes: [CGEventType] = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]
        let eventMask = eventTypes.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << CGEventMask($1.rawValue))
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, eventType, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                return Unmanaged<OMacOSPointerGestureController>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                    .handle(eventType, event: event)
            },
            userInfo: context
        ) else {
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func perform(_ action: String) {
        switch action {
        case "super-down":
            superKeyDown = true
        case "super-up":
            superKeyDown = false
            endGesture()
        case "begin-move":
            beginGesture(.move)
        case "begin-resize":
            beginGesture(.resize)
        case "end":
            endGesture()
        default:
            break
        }
    }

    private func beginGesture(_ gesture: OMacOSPointerGesture) {
        guard superKeyDown,
              let pointer = CGEvent(source: nil)?.location,
              let window = try? OMacOSWindowActions.focusedWindowElement(),
              let frame = try? OMacOSWindowActions.windowFrame(window) else {
            return
        }
        activeGesture = gesture
        activeWindow = window
        initialPointer = pointer
        initialFrame = frame
    }

    private func endGesture() {
        activeGesture = nil
        activeWindow = nil
    }

    private func handle(_ eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if eventType == .scrollWheel, superKeyDown {
            let delta = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            if abs(delta) >= 1, Date().timeIntervalSince(lastWorkspaceScroll) >= 0.18 {
                lastWorkspaceScroll = Date()
                if event.flags.contains(.maskAlternate) {
                    runOMacOSCommand(["group", delta < 0 ? "next" : "previous"])
                } else {
                    runOMacOSCommand(["wm", delta < 0 ? "workspace-next" : "workspace-previous"])
                }
            }
            return nil
        }

        guard let activeGesture, let activeWindow else {
            return Unmanaged.passUnretained(event)
        }
        let pointer = event.location
        let deltaX = pointer.x - initialPointer.x
        let deltaY = pointer.y - initialPointer.y
        var targetFrame = initialFrame
        switch activeGesture {
        case .move:
            targetFrame.origin.x += deltaX
            targetFrame.origin.y += deltaY
        case .resize:
            targetFrame.size.width = max(240, initialFrame.width + deltaX)
            targetFrame.size.height = max(160, initialFrame.height + deltaY)
        }
        try? OMacOSWindowActions.setWindowFrame(targetFrame, window: activeWindow)
        return Unmanaged.passUnretained(event)
    }

    private func runOMacOSCommand(_ arguments: [String]) {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectory = environment["OMACOS_TEST_HOME"] ?? NSHomeDirectory()
        let commandPath = environment["OMACOS_CLI_BINARY"]
            ?? homeDirectory + "/.local/bin/omacos"
        guard FileManager.default.isExecutableFile(atPath: commandPath) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: commandPath)
            process.arguments = arguments
            try? process.run()
        }
    }
}
