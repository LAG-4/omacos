import ApplicationServices
import AVFoundation
import CoreGraphics
import Foundation
import IOKit.hid
import Speech

struct OMacOSPermissionStatus: Codable {
    let schemaVersion: Int
    let accessibility: String
    let screenRecording: String
    let inputMonitoring: String
    let microphone: String
    let speechRecognition: String

    static func current() -> OMacOSPermissionStatus {
        OMacOSPermissionStatus(
            schemaVersion: 1,
            accessibility: AXIsProcessTrusted() ? "granted" : "not-granted",
            screenRecording: CGPreflightScreenCaptureAccess() ? "granted" : "not-granted",
            inputMonitoring: inputMonitoringStatus(),
            microphone: captureAuthorizationStatus(AVCaptureDevice.authorizationStatus(for: .audio)),
            speechRecognition: speechAuthorizationStatus(SFSpeechRecognizer.authorizationStatus())
        )
    }

    private static func inputMonitoringStatus() -> String {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: "granted"
        case kIOHIDAccessTypeDenied: "denied"
        default: "not-determined"
        }
    }

    private static func captureAuthorizationStatus(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: "granted"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "not-determined"
        @unknown default: "unknown"
        }
    }

    private static func speechAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: "granted"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "not-determined"
        @unknown default: "unknown"
        }
    }
}
