import AppKit

let screenSize = NSSize(width: 1920, height: 1080)
let expectedFrames: [OMacOSBarPosition: NSRect] = [
    .top: NSRect(x: 0, y: 1046, width: 1920, height: 34),
    .bottom: NSRect(x: 0, y: 0, width: 1920, height: 34),
    .left: NSRect(x: 0, y: 0, width: 48, height: 1080),
    .right: NSRect(x: 1872, y: 0, width: 48, height: 1080),
]

for position in OMacOSBarPosition.allCases {
    let actualFrame = OMacOSBarGeometry.localPanelFrame(
        screenSize: screenSize,
        position: position
    )
    guard actualFrame == expectedFrames[position] else {
        fputs("Unexpected \(position.rawValue) frame: \(NSStringFromRect(actualFrame))\n", stderr)
        exit(1)
    }
}

print("Bar panel geometry test passed")
