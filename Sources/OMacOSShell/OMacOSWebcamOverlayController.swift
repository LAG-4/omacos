import AppKit
import AVFoundation

final class OMacOSCameraPreviewView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("OMacOSCameraPreviewView does not support NSCoder")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

@MainActor
final class OMacOSWebcamOverlayController {
    private let overlaySizes = [
        NSSize(width: 192, height: 108),
        NSSize(width: 288, height: 162),
        NSSize(width: 384, height: 216)
    ]
    private var sizeIndex = 1
    private var captureSession: AVCaptureSession?
    private var overlayPanel: NSPanel?

    func perform(_ action: String) {
        switch action {
        case "start": start()
        case "stop": stop()
        case "smaller": resize(by: -1)
        case "larger": resize(by: 1)
        default: break
        }
    }

    private func start() {
        if let overlayPanel {
            overlayPanel.orderFrontRegardless()
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showOverlay()
        case .notDetermined:
            Task { [weak self] in
                if await AVCaptureDevice.requestAccess(for: .video) {
                    self?.showOverlay()
                }
            }
        default:
            break
        }
    }

    private func showOverlay() {
        guard overlayPanel == nil,
              let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high
        if session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: overlaySizes[sizeIndex]),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = OMacOSCameraPreviewView(session: session)
        overlayPanel = panel
        captureSession = session
        positionPanel(panel)
        session.startRunning()
        panel.orderFrontRegardless()
    }

    private func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        overlayPanel?.close()
        overlayPanel = nil
    }

    private func resize(by offset: Int) {
        sizeIndex = min(max(sizeIndex + offset, 0), overlaySizes.count - 1)
        guard let overlayPanel else { return }
        overlayPanel.setContentSize(overlaySizes[sizeIndex])
        positionPanel(overlayPanel)
    }

    private func positionPanel(_ panel: NSPanel) {
        let targetScreen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main
        guard let targetScreen else { return }
        let margin: CGFloat = 18
        panel.setFrameOrigin(NSPoint(
            x: targetScreen.visibleFrame.maxX - panel.frame.width - margin,
            y: targetScreen.visibleFrame.minY + margin
        ))
    }
}
