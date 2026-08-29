import AppKit
import AVFoundation
import Combine
import Speech

@MainActor
final class OMacOSDictationController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published private(set) var statusMessage = "Ready for on-device macOS dictation."

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func toggle() {
        if isRecording {
            stopAndInsert()
        } else {
            start()
        }
    }

    func start() {
        guard !isRecording else { return }
        Task { await requestPermissionsAndStart() }
    }

    func stopAndInsert() {
        stopRecording()
        let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else {
            statusMessage = "No speech was recognized."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(finalText, forType: .string)
        pasteIntoFocusedApplication()
        statusMessage = "Dictation inserted into the focused application."
    }

    private func requestPermissionsAndStart() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            statusMessage = "Allow Speech Recognition for OMacOS in Privacy & Security."
            return
        }

        let microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphoneAllowed else {
            statusMessage = "Allow Microphone access for OMacOS in Privacy & Security."
            return
        }

        do {
            try startRecording()
        } catch {
            statusMessage = "Dictation could not start: \(error.localizedDescription)"
        }
    }

    private func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw OMacOSDictationError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        statusMessage = "Listening… press the shortcut again to insert."

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                if error != nil {
                    self?.stopRecording()
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording || recognitionRequest != nil else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func pasteIntoFocusedApplication() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

private enum OMacOSDictationError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        "Speech recognition is currently unavailable for this language."
    }
}
