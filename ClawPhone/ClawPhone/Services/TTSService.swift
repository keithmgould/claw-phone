import Foundation

enum TTSError: LocalizedError {
    case synthesizeFailed(Int)

    var errorDescription: String? {
        switch self {
        case .synthesizeFailed(let code): return "TTS failed with status \(code)"
        }
    }
}

enum TTSService {
    static func synthesize(text: String, apiKey: String, voiceId: String) async throws -> Data {
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TTSError.synthesizeFailed(code)
        }
        return data
    }
}
