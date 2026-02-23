import Speech
import AVFoundation

final class SpeechRecognizer {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 4.0

    // Bug #2: guard against stale "done" callbacks
    private var hasReceivedResult = false
    private var startTime: Date?
    private let graceperiod: TimeInterval = 1.5

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    static func requestPermissions() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening(audioManager: AudioManager) {
        stopListening(audioManager: audioManager)

        hasReceivedResult = false
        startTime = Date()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        var lastTranscript = ""

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.hasReceivedResult = true
                lastTranscript = result.bestTranscription.formattedString

                if result.isFinal {
                    self.silenceTimer?.invalidate()
                    self.stopListening(audioManager: audioManager)
                    if !lastTranscript.isEmpty {
                        self.onFinalResult?(lastTranscript)
                    }
                    return
                }

                self.onPartialResult?(lastTranscript)

                // Reset silence timer on each partial
                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceTimeout, repeats: false) { _ in
                    self.stopListening(audioManager: audioManager)
                    if !lastTranscript.isEmpty {
                        self.onFinalResult?(lastTranscript)
                    }
                }
            }

            if let error {
                // Bug #2: Ignore stale "done" within grace period if no results received
                if !self.hasReceivedResult,
                   let start = self.startTime,
                   Date().timeIntervalSince(start) < self.graceperiod {
                    return
                }

                self.silenceTimer?.invalidate()
                self.stopListening(audioManager: audioManager)

                // If we got a transcript before the error, use it
                if !lastTranscript.isEmpty {
                    self.onFinalResult?(lastTranscript)
                } else {
                    self.onError?(error)
                }
            }
        }

        // Feed audio from shared engine
        audioManager.installInputTap { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
    }

    func stopListening(audioManager: AudioManager) {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioManager.removeInputTap()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
