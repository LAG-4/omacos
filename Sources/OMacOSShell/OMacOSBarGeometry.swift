import AppKit

enum OMacOSBarGeometry {
    static let horizontalBarHeight = CGFloat(OMacOSShellContract.shared.bar.horizontalSize)
    static let verticalBarWidth = CGFloat(OMacOSShellContract.shared.bar.verticalSize)

    /// Returns an AppKit global-screen frame, preserving non-zero and negative display origins.
    static func panelFrame(
        screenFrame: NSRect,
        position: OMacOSBarPosition
    ) -> NSRect {
        switch position {
        case .top:
            NSRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - horizontalBarHeight,
                width: screenFrame.width,
                height: horizontalBarHeight
            )
        case .bottom:
            NSRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: horizontalBarHeight
            )
        case .left:
            NSRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: verticalBarWidth,
                height: screenFrame.height
            )
        case .right:
            NSRect(
                x: screenFrame.maxX - verticalBarWidth,
                y: screenFrame.minY,
                width: verticalBarWidth,
                height: screenFrame.height
            )
        }
    }
}
