import SwiftUI

struct HomeView: View {
    @Environment(SettingsManager.self) private var settings
    @State private var voiceLoop = VoiceLoopManager()
    @State private var showSettings = false

    private var isRunning: Bool {
        voiceLoop.state != .idle
    }

    private var statusIcon: String {
        switch voiceLoop.state {
        case .idle: return "mic.slash"
        case .listening: return "mic.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var statusLabel: String {
        switch voiceLoop.state {
        case .idle: return "Tap to begin"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        case .error(let msg): return msg
        }
    }

    private var statusColor: Color {
        switch voiceLoop.state {
        case .idle: return .gray
        case .listening: return .red
        case .processing: return .orange
        case .speaking: return .blue
        case .error: return .red
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Conversation list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(voiceLoop.messages) { message in
                                MessageBubbleView(role: message.role, content: message.content)
                                    .id(message.id)
                            }

                            // Partial transcript (user is speaking)
                            if !voiceLoop.partialTranscript.isEmpty {
                                MessageBubbleView(
                                    role: "user",
                                    content: voiceLoop.partialTranscript,
                                    isPartial: true
                                )
                                .id("partial-transcript")
                            }

                            // Partial response (assistant is generating)
                            if !voiceLoop.partialResponse.isEmpty {
                                MessageBubbleView(
                                    role: "assistant",
                                    content: voiceLoop.partialResponse,
                                    isPartial: true
                                )
                                .id("partial-response")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: voiceLoop.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: voiceLoop.partialTranscript) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: voiceLoop.partialResponse) {
                        scrollToBottom(proxy: proxy)
                    }
                }

                Divider()

                // Status + Mic button
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text(statusLabel)
                            .font(.subheadline)
                            .foregroundColor(statusColor)
                    }
                    .padding(.top, 12)

                    HStack {
                        Text(settings.model)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Button {
                            if isRunning {
                                voiceLoop.stop()
                            } else {
                                voiceLoop.start(settings: settings)
                            }
                        } label: {
                            Image(systemName: isRunning ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .frame(width: 80, height: 80)
                                .background(isRunning ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .disabled(!settings.isConfigured && !isRunning)

                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Claw Phone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        voiceLoop.clearMessages()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isRunning || voiceLoop.messages.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                if !settings.isConfigured {
                    showSettings = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startListeningIntent)) { _ in
                if !isRunning && settings.isConfigured {
                    voiceLoop.start(settings: settings)
                }
            }
        }
        .tint(.purple)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if !voiceLoop.partialResponse.isEmpty {
            proxy.scrollTo("partial-response", anchor: .bottom)
        } else if !voiceLoop.partialTranscript.isEmpty {
            proxy.scrollTo("partial-transcript", anchor: .bottom)
        } else if let last = voiceLoop.messages.last {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
