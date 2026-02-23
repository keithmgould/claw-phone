import AVFoundation

final class AudioManager: NSObject, AVAudioPlayerDelegate {
    let audioEngine = AVAudioEngine()
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    private var inputTapInstalled = false

    // MARK: - VAD
    var onBargeInDetected: (() -> Void)?
    private var vadActive = false
    private var speechStartTime: Date?
    private let speechThresholdDb: Float = -40.0
    private let sustainedDuration: TimeInterval = 0.2

    // MARK: - Session Configuration (call ONCE)

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true)
    }

    func enableVoiceProcessing() throws {
        try audioEngine.inputNode.setVoiceProcessingEnabled(true)
        try audioEngine.outputNode.setVoiceProcessingEnabled(true)
    }

    // MARK: - Engine

    func startEngine() throws {
        guard !audioEngine.isRunning else { return }
        try audioEngine.start()
    }

    func stopEngine() {
        if inputTapInstalled {
            removeInputTap()
        }
        audioEngine.stop()
    }

    // MARK: - Input Tap Management

    func installInputTap(handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {
        guard !inputTapInstalled else { return }
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: handler)
        inputTapInstalled = true
    }

    func removeInputTap() {
        guard inputTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        inputTapInstalled = false
    }

    // MARK: - Playback

    func playAudio(_ mp3Data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                audioPlayer = try AVAudioPlayer(data: mp3Data)
                audioPlayer?.delegate = self
                playbackContinuation = continuation
                audioPlayer?.play()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        let cont = playbackContinuation
        playbackContinuation = nil
        cont?.resume()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let cont = playbackContinuation
        playbackContinuation = nil
        cont?.resume()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let cont = playbackContinuation
        playbackContinuation = nil
        cont?.resume(throwing: error ?? NSError(domain: "AudioManager", code: -1))
    }

    // MARK: - VAD Monitoring

    func startVADMonitoring() {
        vadActive = true
        speechStartTime = nil

        installInputTap { [weak self] buffer, _ in
            guard let self, self.vadActive else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            var rms: Float = 0
            for i in 0..<frameLength {
                rms += channelData[i] * channelData[i]
            }
            rms = sqrt(rms / Float(frameLength))
            let db = 20 * log10(max(rms, 1e-10))

            if db > self.speechThresholdDb {
                if self.speechStartTime == nil {
                    self.speechStartTime = Date()
                } else if Date().timeIntervalSince(self.speechStartTime!) >= self.sustainedDuration {
                    self.vadActive = false
                    DispatchQueue.main.async {
                        self.onBargeInDetected?()
                    }
                }
            } else {
                self.speechStartTime = nil
            }
        }
    }

    func stopVADMonitoring() {
        vadActive = false
        speechStartTime = nil
        removeInputTap()
    }
}
