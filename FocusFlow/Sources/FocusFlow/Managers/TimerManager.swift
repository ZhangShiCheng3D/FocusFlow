import Combine
import Foundation

// MARK: - Timer Manager

@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false

    private var timer: Timer?
    private var endDate: Date?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(totalSeconds - remainingSeconds) / Double(totalSeconds)))
    }

    var remainingFormatted: String {
        let secs = max(0, remainingSeconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let seconds = secs % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var remainingCompactFormatted: String {
        let secs = max(0, remainingSeconds)
        let minutes = (secs % 3600) / 60
        let hours = secs / 3600
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        return "\(minutes)m"
    }

    func startDuration(minutes: Int) {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        isRunning = true
        isPaused = false
        startTick()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isPaused = false
        startTick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        remainingSeconds = 0
        totalSeconds = 0
        endDate = nil
    }

    private func startTick() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        // Use .common run loop mode so the timer fires even during
        // menu tracking, popover display, and other modal run loop modes.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isRunning, !isPaused else { return }

        // Use wall-clock time to avoid drift over long sessions.
        // Timer(1s) can jitter by tens of ms per tick, accumulating
        // to noticeable error over 60+ minute sessions.
        if let end = endDate {
            let remaining = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
            remainingSeconds = remaining
        }

        if remainingSeconds <= 0 {
            stop()
            NotificationCenter.default.post(name: .focusTimerDidFinish, object: nil)
        }
    }

    // For status bar display
    var statusBarText: String {
        guard isRunning else { return "" }
        let secs = max(0, remainingSeconds)
        if secs >= 3600 {
            return String(format: "%d:%02d", secs / 3600, (secs % 3600) / 60)
        }
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }
}

extension Notification.Name {
    static let focusTimerDidFinish = Notification.Name("focusTimerDidFinish")
}
