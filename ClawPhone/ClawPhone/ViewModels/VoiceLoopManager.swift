import Foundation
import AVFoundation
import Speech

@Observable
final class VoiceLoopManager {
    var state: VoiceLoopState = .idle
    var messages: [Message] = []
    var partialTranscript: String = ""
    var partialResponse: String = ""

    private let audioManager = AudioManager()
    private let speechRecognizer = SpeechRecognizer()
    private var loopTask: Task<Void, Never>?
    private var bargeInDetected = false

    // Sentence boundary regex
    private let sentencePattern = try! NSRegularExpression(pattern: "^(.*?[.!?])\\s+")

    func start(settings: SettingsManager) {
        guard state == .idle else { return }
        loopTask = Task { @MainActor in
            do {
                // Request permissions
                let speechAuthorized = await SpeechRecognizer.requestPermissions()
                guard speechAuthorized else {
                    state = .error("Speech recognition permission denied")
                    return
                }

                // Request mic permission
                let micAuthorized = await AVAudioApplication.requestRecordPermission()
                guard micAuthorized else {
                    state = .error("Microphone permission denied")
                    return
                }

                // Configure audio once
                try audioManager.configureSession()
                try audioManager.enableVoiceProcessing()
                try audioManager.startEngine()

                // Enter listening loop
                await enterListeningLoop(settings: settings)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        speechRecognizer.stopListening(audioManager: audioManager)
        audioManager.stopPlayback()
        audioManager.stopVADMonitoring()
        audioManager.stopEngine()
        state = .idle
        partialTranscript = ""
        partialResponse = ""
    }

    func clearMessages() {
        messages.removeAll()
        partialTranscript = ""
        partialResponse = ""
    }

    // MARK: - Main Loop

    @MainActor
    private func enterListeningLoop(settings: SettingsManager) async {
        while !Task.isCancelled {
            do {
                // Listen
                let transcript = try await listen()
                guard !Task.isCancelled, !transcript.isEmpty else { continue }

                // Bug #6: Clear partial before adding final message
                partialTranscript = ""
                messages.append(Message(role: "user", content: transcript))

                // Process + Speak (with sentence pipelining and barge-in)
                try await processAndSpeak(userMessage: transcript, settings: settings)

            } catch is CancellationError {
                break
            } catch {
                if Task.isCancelled { break }
                state = .error(error.localizedDescription)
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
            }
        }
    }

    // MARK: - Listen Phase

    @MainActor
    private func listen() async throws -> String {
        state = .listening
        partialTranscript = ""

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            speechRecognizer.onPartialResult = { [weak self] text in
                Task { @MainActor in
                    self?.partialTranscript = text
                }
            }

            speechRecognizer.onFinalResult = { text in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: text)
            }

            speechRecognizer.onError = { error in
                guard !resumed else { return }
                resumed = true
                // On error with no result, return empty string to retry
                continuation.resume(returning: "")
            }

            speechRecognizer.startListening(audioManager: audioManager)
        }
    }

    // MARK: - Process + Speak (Phase 6: Sentence Pipelining)

    @MainActor
    private func processAndSpeak(userMessage: String, settings: SettingsManager) async throws {
        state = .processing
        partialResponse = ""
        bargeInDetected = false

        let apiMessages = ChatService.buildAPIMessages(
            history: messages,
            userMessage: userMessage
        )

        let stream = ChatService.streamChat(
            messages: apiMessages,
            gatewayUrl: settings.sanitizedGatewayUrl,
            gatewayToken: settings.gatewayToken,
            model: settings.model
        )

        var fullResponse = ""
        var sentenceBuffer = ""
        var ttsTasks: [Task<Data, Error>] = []

        // Stream LLM tokens and fire TTS for each sentence
        for try await chunk in stream {
            if Task.isCancelled || bargeInDetected { break }

            fullResponse += chunk
            sentenceBuffer += chunk
            partialResponse = fullResponse

            // Detect sentence boundaries and queue TTS
            while let match = sentenceBuffer.range(
                of: "^(.*?[.!?])\\s+",
                options: .regularExpression
            ) {
                let sentence = String(sentenceBuffer[match]).trimmingCharacters(in: .whitespaces)
                sentenceBuffer = String(sentenceBuffer[match.upperBound...])

                let apiKey = settings.elevenLabsKey
                let voiceId = settings.elevenLabsVoiceId
                let task = Task<Data, Error> {
                    try await TTSService.synthesize(text: sentence, apiKey: apiKey, voiceId: voiceId)
                }
                ttsTasks.append(task)
            }
        }

        // Flush remaining buffer
        let remaining = sentenceBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty && !bargeInDetected {
            let apiKey = settings.elevenLabsKey
            let voiceId = settings.elevenLabsVoiceId
            let task = Task<Data, Error> {
                try await TTSService.synthesize(text: remaining, apiKey: apiKey, voiceId: voiceId)
            }
            ttsTasks.append(task)
        }

        // Add assistant message
        if !fullResponse.isEmpty {
            messages.append(Message(role: "assistant", content: fullResponse))
        }
        partialResponse = ""

        // Play audio in order (Phase 7: with barge-in VAD)
        if !ttsTasks.isEmpty && !bargeInDetected {
            state = .speaking

            // Start VAD monitoring for barge-in
            audioManager.onBargeInDetected = { [weak self] in
                self?.bargeInDetected = true
                self?.audioManager.stopPlayback()
                self?.audioManager.stopVADMonitoring()
            }
            audioManager.startVADMonitoring()

            for task in ttsTasks {
                if Task.isCancelled || bargeInDetected { break }
                do {
                    let audioData = try await task.value
                    if Task.isCancelled || bargeInDetected { break }
                    try await audioManager.playAudio(audioData)
                } catch {
                    if bargeInDetected { break }
                    throw error
                }
            }

            audioManager.stopVADMonitoring()

            // Cancel remaining TTS tasks on barge-in
            if bargeInDetected {
                for task in ttsTasks { task.cancel() }
            }
        }
    }
}
