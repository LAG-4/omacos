import AppKit

enum OMacOSBarGeometry {
    static let horizontalBarHeight: CGFloat = 34
    static let verticalBarWidth: CGFloat = 48

    /// Returns a screen-local frame for NSWindow initializers that receive an explicit screen.
    static func localPanelFrame(
        screenSize: NSSize,
        position: OMacOSBarPosition
    ) -> NSRect {
        switch position {
        case .top:
            NSRect(
                x: 0,
                y: screenSize.height - horizontalBarHeight,
                width: screenSize.width,
                height: horizontalBarHeight
            )
        case .bottom:
            NSRect(
                x: 0,
                y: 0,
                width: screenSize.width,
                height: horizontalBarHeight
            )
        case .left:
            NSRect(
                x: 0,
                y: 0,
                width: verticalBarWidth,
                height: screenSize.height
            )
        case .right:
            NSRect(
                x: screenSize.width - verticalBarWidth,
                y: 0,
                width: verticalBarWidth,
                height: screenSize.height
            )
        }
    }
}
