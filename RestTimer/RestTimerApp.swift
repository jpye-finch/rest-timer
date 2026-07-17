import SwiftUI
import UserNotifications

@main
struct RestTimerApp: App {
    // A single shared timer model drives both the UI and the notification actions.
    @StateObject private var timer = RestTimerModel()

    init() {
        NotificationManager.shared.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timer)
                .onAppear {
                    // Route notification action taps back into the shared model.
                    NotificationManager.shared.timer = timer
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
