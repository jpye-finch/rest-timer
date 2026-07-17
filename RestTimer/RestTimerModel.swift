import Foundation
import Combine
import UIKit

/// Drives the rest countdown. Time is tracked against an absolute `endDate`
/// so the countdown stays accurate across backgrounding, and a local
/// notification is scheduled for that same date so the alert fires even
/// when the app is suspended.
@MainActor
final class RestTimerModel: ObservableObject {

    /// Preset rest durations in seconds, shown as quick-select chips.
    static let presets: [Int] = [30, 60, 90, 120, 150, 180, 240, 300]

    @Published var selectedSeconds: Int = 90
    @Published private(set) var remaining: TimeInterval = 90
    @Published private(set) var isRunning: Bool = false
    /// True for the brief "GO" moment after a rest completes.
    @Published private(set) var finished: Bool = false

    /// How close the countdown is to zero — drives the ring's colour.
    enum Urgency {
        case normal   // plenty of time
        case warning  // final 20s
        case urgent   // final 10s
    }

    var urgency: Urgency {
        guard isRunning else { return .normal }
        if remaining <= 10 { return .urgent }
        if remaining <= 20 { return .warning }
        return .normal
    }

    private var endDate: Date?
    private var ticker: AnyCancellable?

    // MARK: - Duration selection

    /// Pick a duration. Resets the displayed countdown when idle so the
    /// selection is reflected immediately.
    func select(seconds: Int) {
        let clamped = max(1, min(seconds, 3600))
        selectedSeconds = clamped
        if !isRunning {
            finished = false
            remaining = TimeInterval(clamped)
        }
    }

    var isCustomSelection: Bool {
        !Self.presets.contains(selectedSeconds)
    }

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        // Resume from a paused remaining value, otherwise start fresh.
        let seconds = remaining > 0 ? remaining : TimeInterval(selectedSeconds)
        beginCountdown(from: seconds)
    }

    func pause() {
        guard isRunning else { return }
        remaining = max(0, (endDate ?? Date()).timeIntervalSinceNow)
        stopTicker()
        isRunning = false
        endDate = nil
        NotificationManager.shared.cancelPending()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// Restart the currently selected duration from the beginning.
    /// Invoked both from the UI and from the notification "Reset" action.
    func reset() {
        beginCountdown(from: TimeInterval(selectedSeconds))
    }

    /// Stop entirely and return to the idle, full-duration state.
    func clear() {
        stopTicker()
        isRunning = false
        finished = false
        endDate = nil
        remaining = TimeInterval(selectedSeconds)
        NotificationManager.shared.cancelPending()
    }

    /// Add seconds to a running (or paused) timer.
    func addSeconds(_ seconds: Int) {
        if isRunning, let end = endDate {
            let newEnd = end.addingTimeInterval(TimeInterval(seconds))
            endDate = newEnd
            remaining = max(0, newEnd.timeIntervalSinceNow)
            NotificationManager.shared.scheduleCompletion(at: newEnd, seconds: selectedSeconds)
        } else {
            remaining = max(1, remaining + TimeInterval(seconds))
        }
    }

    // MARK: - Internals

    private func beginCountdown(from seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        endDate = end
        remaining = seconds
        isRunning = true
        finished = false
        startTicker()
        NotificationManager.shared.scheduleCompletion(at: end, seconds: selectedSeconds)
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard let end = endDate else { return }
        let left = end.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            complete()
        } else {
            remaining = left
        }
    }

    private func complete() {
        stopTicker()
        isRunning = false
        finished = true
        endDate = nil
        // The scheduled notification handles the alert; give haptic feedback
        // if the app happens to be foregrounded.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Formatting

    var displayText: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var progress: Double {
        let total = TimeInterval(selectedSeconds)
        guard total > 0 else { return 0 }
        return min(1, max(0, remaining / total))
    }
}
