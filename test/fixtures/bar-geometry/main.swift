import AppKit

let screenFrame = NSRect(x: 1920, y: -120, width: 2560, height: 1440)
let expectedFrames: [OMacOSBarPosition: NSRect] = [
    .top: NSRect(x: 1920, y: 1294, width: 2560, height: 26),
    .bottom: NSRect(x: 1920, y: -120, width: 2560, height: 26),
    .left: NSRect(x: 1920, y: -120, width: 28, height: 1440),
    .right: NSRect(x: 4452, y: -120, width: 28, height: 1440),
]

for position in OMacOSBarPosition.allCases {
    let actualFrame = OMacOSBarGeometry.panelFrame(
        screenFrame: screenFrame,
        position: position
    )
    guard actualFrame == expectedFrames[position] else {
        fputs("Unexpected \(position.rawValue) frame: \(NSStringFromRect(actualFrame))\n", stderr)
        exit(1)
    }
}

print("Bar panel geometry test passed")
