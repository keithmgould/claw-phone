import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var gatewayUrl = ""
    @State private var gatewayToken = ""
    @State private var elevenLabsKey = ""
    @State private var elevenLabsVoiceId = ""
    @State private var model = "claude-sonnet-4-6"

    private var allFieldsFilled: Bool {
        !gatewayUrl.isEmpty && !gatewayToken.isEmpty &&
        !elevenLabsKey.isEmpty && !elevenLabsVoiceId.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gateway") {
                    TextField("https://your-gateway.example.com", text: $gatewayUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Gateway Token", text: $gatewayToken)
                }

                Section("Model") {
                    Picker("Model", selection: $model) {
                        Text("Sonnet 4.6 — Fast").tag("claude-sonnet-4-6")
                        Text("Opus 4.6 — Smarter").tag("claude-opus-4-6")
                        Text("Haiku 4.5 — Fastest").tag("claude-haiku-4-5-20251001")
                    }
                }

                Section("ElevenLabs") {
                    SecureField("API Key", text: $elevenLabsKey)
                    TextField("Voice ID (e.g. cgSgspJ2msm6clMCkdW9)", text: $elevenLabsVoiceId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Button("Save") {
                    settings.gatewayUrl = gatewayUrl
                    settings.gatewayToken = gatewayToken
                    settings.elevenLabsKey = elevenLabsKey
                    settings.elevenLabsVoiceId = elevenLabsVoiceId
                    settings.model = model
                    settings.save()
                    dismiss()
                }
                .disabled(!allFieldsFilled)
                .frame(maxWidth: .infinity)

                Section {
                    Text("v1.0.3")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                gatewayUrl = settings.gatewayUrl
                gatewayToken = settings.gatewayToken
                elevenLabsKey = settings.elevenLabsKey
                elevenLabsVoiceId = settings.elevenLabsVoiceId
                model = settings.model
            }
        }
    }
}
