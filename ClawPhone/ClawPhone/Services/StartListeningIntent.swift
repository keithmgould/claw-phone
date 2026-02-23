import AppIntents
import Foundation

struct StartListeningIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Listening"
    static var description: IntentDescription = "Opens Claw Phone and starts listening for voice input."
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .startListeningIntent, object: nil)
        return .result()
    }
}

extension Notification.Name {
    static let startListeningIntent = Notification.Name("startListeningIntent")
}

struct ClawPhoneShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartListeningIntent(),
            phrases: [
                "Start listening with \(.applicationName)",
                "Open \(.applicationName)",
            ],
            shortTitle: "Start Listening",
            systemImageName: "mic.fill"
        )
    }
}
