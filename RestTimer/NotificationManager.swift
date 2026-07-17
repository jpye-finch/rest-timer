import Foundation
import UserNotifications

/// Owns local-notification permission, scheduling, and the interactive
/// actions attached to the rest-complete alert — including the "Reset"
/// action that restarts the timer straight from the notification.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    /// Set by the app at launch so notification actions can drive the timer.
    weak var timer: RestTimerModel?

    private let center = UNUserNotificationCenter.current()

    private let categoryID = "REST_COMPLETE"
    private let requestID = "REST_TIMER_COMPLETE"

    private enum Action: String {
        case reset = "RESET_ACTION"
        case addMinute = "ADD_MINUTE_ACTION"
    }

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Setup

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Register the notification category and its action buttons. The "Reset"
    /// button restarts the rest interval without the user reopening the app.
    func registerCategories() {
        let reset = UNNotificationAction(
            identifier: Action.reset.rawValue,
            title: "Reset Timer",
            options: [.foreground]
        )
        let addMinute = UNNotificationAction(
            identifier: Action.addMinute.rawValue,
            title: "+1:00",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [reset, addMinute],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Scheduling

    /// Schedule the rest-complete alert for an absolute date.
    func scheduleCompletion(at date: Date, seconds: Int) {
        cancelPending()

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Your \(Self.label(for: seconds)) rest is up — back to work."
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
    }

    private static func label(for seconds: Int) -> String {
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        return "\(seconds)s"
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle the action buttons on the delivered notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = Action(rawValue: response.actionIdentifier)
        Task { @MainActor in
            switch action {
            case .reset:
                self.timer?.reset()
            case .addMinute:
                self.timer?.select(seconds: (self.timer?.selectedSeconds ?? 60))
                self.timer?.reset()
                self.timer?.addSeconds(60)
            case .none:
                break
            }
            completionHandler()
        }
    }

    /// Show the banner even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
