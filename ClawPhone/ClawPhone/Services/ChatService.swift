import Foundation

enum ChatError: LocalizedError {
    case badURL
    case badStatus(Int, String)
    case noData

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid gateway URL"
        case .badStatus(let code, let body): return "HTTP \(code): \(body)"
        case .noData: return "No data received"
        }
    }
}

enum ChatService {
    static let systemPrompt = """
        This conversation is happening via real-time voice chat. Your responses will be \
        read aloud by a text-to-speech engine. Keep responses concise and conversational — \
        a few sentences at most unless the topic genuinely needs depth. No markdown, bullet \
        points, code blocks, or special formatting. Never include URLs, long IDs, or anything \
        unpleasant to hear spoken aloud. Summarize such details naturally instead of reading \
        them verbatim.
        """

    static let historyWindowSize = 10

    static func buildAPIMessages(history: [Message], userMessage: String) -> [[String: String]] {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        let windowStart = max(0, history.count - historyWindowSize)
        for i in windowStart..<history.count {
            apiMessages.append(history[i].toDict())
        }
        apiMessages.append(["role": "user", "content": userMessage])
        return apiMessages
    }

    static func streamChat(
        messages: [[String: String]],
        gatewayUrl: String,
        gatewayToken: String,
        model: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "\(gatewayUrl)/v1/chat/completions") else {
                        continuation.finish(throwing: ChatError.badURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(gatewayToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let body: [String: Any] = [
                        "model": model,
                        "user": "claw-phone-user",
                        "messages": messages,
                        "max_tokens": 500,
                        "temperature": 0.7,
                        "stream": true,
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatError.noData)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: ChatError.badStatus(httpResponse.statusCode, errorBody))
                        return
                    }

                    // URLSession.bytes.lines handles TCP chunk buffering (Bug #3)
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        if trimmed == "data: [DONE]" { break }
                        guard trimmed.hasPrefix("data: ") else { continue }

                        let jsonStr = String(trimmed.dropFirst(6))
                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String,
                              !content.isEmpty else {
                            continue
                        }

                        continuation.yield(content)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
