import AppKit
import Foundation
import Vision

enum OMacOSVisionRecognizer {
    /// Runs Apple's on-device text recognition and returns observations in visual reading order.
    static func recognizeText(at imageURL: URL) throws -> String {
        let cgImage = try loadCGImage(at: imageURL)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let rawObservations: [VNRecognizedTextObservation] = request.results ?? []
        let observations = rawObservations.sorted { first, second in
            let verticalDifference = first.boundingBox.midY - second.boundingBox.midY
            if abs(verticalDifference) > 0.02 {
                return verticalDifference > 0
            }
            return first.boundingBox.minX < second.boundingBox.minX
        }

        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// Detects the first QR code with Apple's on-device Vision framework.
    static func recognizeQRCode(at imageURL: URL) throws -> String {
        let cgImage = try loadCGImage(at: imageURL)
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        return request.results?.first?.payloadStringValue ?? ""
    }

    private static func loadCGImage(at imageURL: URL) throws -> CGImage {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OMacOSVisionRecognizerError.invalidImage
        }
        return cgImage
    }
}

enum OMacOSVisionRecognizerError: Error {
    case invalidImage
}
