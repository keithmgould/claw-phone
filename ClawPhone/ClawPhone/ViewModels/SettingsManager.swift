import Foundation

@Observable
final class SettingsManager {
    var gatewayUrl: String = ""
    var gatewayToken: String = ""
    var elevenLabsKey: String = ""
    var elevenLabsVoiceId: String = ""
    var model: String = ""

    var isConfigured: Bool {
        !gatewayUrl.isEmpty && !gatewayToken.isEmpty &&
        !elevenLabsKey.isEmpty && !elevenLabsVoiceId.isEmpty
    }

    var sanitizedGatewayUrl: String {
        var url = gatewayUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }

    init() {
        load()
    }

    func load() {
        gatewayUrl = KeychainHelper.load(key: "gateway_url") ?? ""
        gatewayToken = KeychainHelper.load(key: "gateway_token") ?? ""
        elevenLabsKey = KeychainHelper.load(key: "elevenlabs_key") ?? ""
        elevenLabsVoiceId = KeychainHelper.load(key: "elevenlabs_voice_id") ?? "cgSgspJ2msm6clMCkdW9"
        model = KeychainHelper.load(key: "model") ?? "main"
    }

    func save() {
        KeychainHelper.save(key: "gateway_url", value: gatewayUrl)
        KeychainHelper.save(key: "gateway_token", value: gatewayToken)
        KeychainHelper.save(key: "elevenlabs_key", value: elevenLabsKey)
        KeychainHelper.save(key: "elevenlabs_voice_id", value: elevenLabsVoiceId)
        KeychainHelper.save(key: "model", value: model)
    }
}
