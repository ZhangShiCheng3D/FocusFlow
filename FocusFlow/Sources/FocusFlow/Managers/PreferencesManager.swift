import Foundation
import Combine
import ServiceManagement

// MARK: - Preferences Manager

@MainActor
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published var launchAtLogin: Bool {
        didSet {
            save("launchAtLogin", value: launchAtLogin)
            if didFinishInit { setLaunchAtLogin(launchAtLogin) }
        }
    }
    private var didFinishInit = false
    @Published var useGlobalHotkey: Bool {
        didSet { save("useGlobalHotkey", value: useGlobalHotkey) }
    }
    @Published var hotkeyCombo: String {
        didSet { save("hotkeyCombo", value: hotkeyCombo) }
    }
    @Published var defaultDuration: Int {
        didSet { save("defaultDuration", value: defaultDuration) }
    }
    @Published var countdownDisplayMode: CountdownDisplayMode {
        didSet { save("countdownDisplayMode", value: countdownDisplayMode.rawValue) }
    }
    @Published var autoEnableFocus: Bool {
        didSet { save("autoEnableFocus", value: autoEnableFocus) }
    }
    @Published var autoBlockApps: Bool {
        didSet { save("autoBlockApps", value: autoBlockApps) }
    }
    @Published var autoSyncCalendar: Bool {
        didSet { save("autoSyncCalendar", value: autoSyncCalendar) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { save("hasCompletedOnboarding", value: hasCompletedOnboarding) }
    }
    @Published var showSlackBranding: Bool {
        didSet { save("showSlackBranding", value: showSlackBranding) }
    }
    @Published var isIMSyncEnabled: Bool {
        didSet { save("isIMSyncEnabled", value: isIMSyncEnabled) }
    }

    enum CountdownDisplayMode: String, CaseIterable {
        case full = "HH:MM"
        case compact = "25m"
        case pie = "Pie"
        case widget = "Floating"
    }

    private let defaults = UserDefaults.standard

    private init() {
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.useGlobalHotkey = defaults.bool(forKey: "useGlobalHotkey")
        self.hotkeyCombo = defaults.string(forKey: "hotkeyCombo") ?? ""
        self.defaultDuration = defaults.integer(forKey: "defaultDuration").nonZero ?? 25
        self.countdownDisplayMode = CountdownDisplayMode(
            rawValue: defaults.string(forKey: "countdownDisplayMode") ?? "HH:MM"
        ) ?? .full
        self.autoEnableFocus = defaults.bool(forKey: "autoEnableFocus")
        self.autoBlockApps = defaults.bool(forKey: "autoBlockApps")
        self.autoSyncCalendar = defaults.bool(forKey: "autoSyncCalendar")
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        self.showSlackBranding = defaults.bool(forKey: "showSlackBranding")
        self.isIMSyncEnabled = defaults.bool(forKey: "isIMSyncEnabled")
        self.didFinishInit = true
    }

    private func save(_ key: String, value: Any?) {
        defaults.set(value, forKey: key)
    }

    /// Registers or unregisters the app as a login item using SMAppService (macOS 13+).
    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Preferences] Failed to toggle login item: \(error)")
        }
    }

    func resetAll() {
        let domain = Bundle.main.bundleIdentifier ?? "com.focusflow.app"
        defaults.removePersistentDomain(forName: domain)

        // Reset in-memory @Published properties to defaults.
        // Suppress didSet side-effects during bulk reset to avoid
        // redundant saves and SMAppService calls.
        let wasFinished = didFinishInit
        didFinishInit = false

        launchAtLogin = false
        useGlobalHotkey = false
        hotkeyCombo = ""
        defaultDuration = 25
        countdownDisplayMode = .full
        autoEnableFocus = false
        autoBlockApps = false
        autoSyncCalendar = false
        hasCompletedOnboarding = false
        showSlackBranding = false
        isIMSyncEnabled = false

        didFinishInit = wasFinished

        // Ensure SMAppService is in sync with the reset state
        try? SMAppService.mainApp.unregister()
    }
}

extension Int {
    var nonZero: Int? {
        return self == 0 ? nil : self
    }
}

// MARK: - Statistics Manager

@MainActor
final class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()

    @Published var sessions: [FocusSession] = []
    @Published var todayTotalMinutes: Int = 0
    @Published var weekTotalMinutes: Int = 0
    @Published var monthTotalMinutes: Int = 0

    private let defaults = UserDefaults.standard
    private let sessionsKey = "focus_sessions"

    private init() {
        loadSessions()
        recalculateStats()
    }

    func recordSession(_ session: FocusSession) {
        sessions.append(session)
        saveSessions()
        recalculateStats()
    }

    private func loadSessions() {
        guard let data = defaults.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded
    }

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: sessionsKey)
    }

    private func recalculateStats() {
        let calendar = Calendar.current
        let now = Date()

        todayTotalMinutes = sessions
            .filter { calendar.isDate($0.startTime, inSameDayAs: now) }
            .reduce(0) { $0 + $1.durationMinutes }

        if let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
            weekTotalMinutes = sessions
                .filter { $0.startTime >= weekStart }
                .reduce(0) { $0 + $1.durationMinutes }
        }

        if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) {
            monthTotalMinutes = sessions
                .filter { $0.startTime >= monthStart }
                .reduce(0) { $0 + $1.durationMinutes }
        }
    }

    // MARK: - Heatmap Data

    func sessionsForLastDays(_ days: Int) -> [Date: Int] {
        let calendar = Calendar.current
        let now = Date()
        var result: [Date: Int] = [:]

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let dayMinutes = sessions
                .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
                .reduce(0) { $0 + $1.durationMinutes }
            result[dayStart] = dayMinutes
        }

        return result
    }
}
