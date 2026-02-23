import SwiftUI

@main
struct ClawPhoneApp: App {
    @State private var settings = SettingsManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(settings)
                .preferredColorScheme(.dark)
                .tint(.purple)
        }
    }
}
