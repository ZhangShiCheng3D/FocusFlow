import Combine
import Foundation
import AppKit
import EventKit

// MARK: - Focus State Manager

@MainActor
final class FocusStateManager: ObservableObject {
    static let shared = FocusStateManager()

    @Published var focusState: FocusState = .idle
    @Published private(set) var lastAutomationWarning: String?

    var isIMSyncEnabled: Bool { PreferencesManager.shared.isIMSyncEnabled }
    var isSessionActive: Bool {
        if currentSessionStart != nil || isStartingFocus { return true }
        if case .focusing = focusState { return true }
        if case .paused = focusState { return true }
        return false
    }

    private let audioManager = AudioManager.shared
    private let timerManager = TimerManager.shared

    /// Captured at the start of a focus session; used when recording the session
    /// so that stop() zeroing totalSeconds doesn't lose data.
    private var currentSessionStart: Date?
    private var currentSessionDurationSeconds: Int = 0
    private var currentSessionSoundIds: [String] = []
    private var currentSessionID: UUID?
    private var isStartingFocus = false

    private var timerFinishObserver: NSObjectProtocol?

    private init() {
        // Observe timer finish to auto-end focus session
        timerFinishObserver = NotificationCenter.default.addObserver(
            forName: .focusTimerDidFinish, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.endFocus(completed: true)
            }
        }
    }

    // MARK: - Start Focus

    func startFocus(durationMinutes: Int, soundIds: [String], volumes: [String: Float] = [:]) async {
        guard durationMinutes > 0 else { return }
        guard !isSessionActive else { return }

        isStartingFocus = true
        defer { isStartingFocus = false }

        let now = Date()
        let sessionID = UUID()
        let sessionSoundIds = normalizedSoundIds(soundIds)

        focusState = .focusing(
            endTime: now.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            duration: durationMinutes
        )

        // Capture session metadata before anything can mutate it
        currentSessionStart = now
        currentSessionDurationSeconds = durationMinutes * 60
        currentSessionSoundIds = sessionSoundIds
        currentSessionID = sessionID
        lastAutomationWarning = nil

        // 1. Pre-download any uncached sounds via ODRManager for progress UI,
        //    then start audio playback.
        for soundId in sessionSoundIds {
            guard let sound = SoundCatalog.allSounds.first(where: { $0.id == soundId }) else { continue }

            if !ODRManager.shared.isSoundDownloaded(sound) {
                do {
                    try await ODRManager.shared.downloadSound(sound)
                } catch {
                    print("[FocusState] ODR download failed for '\(sound.name)': \(error)")
                    // Continue to playSound — AudioManager.loadBuffer will attempt
                    // a direct download as a last-resort fallback.
                }
            }

            guard isCurrentSession(sessionID) else { return }

            let vol = volumes[soundId] ?? 0.7
            do {
                try await audioManager.playSound(sound, volume: vol)
            } catch {
                print("[FocusState] Failed to play '\(sound.name)': \(error)")
            }

            guard isCurrentSession(sessionID) else {
                audioManager.stopSound(sound.id)
                return
            }
        }

        // 2. Enable macOS Focus (Shortcuts bridge)
        if PreferencesManager.shared.autoEnableFocus {
            await enableSystemFocus()
            guard isCurrentSession(sessionID) else {
                await disableSystemFocus()
                return
            }
        }

        // 3. Sync IM status (independent of macOS focus mode)
        if isIMSyncEnabled {
            await IntegrationManager.shared.setAllStatuses(.focusing(until: now.addingTimeInterval(TimeInterval(durationMinutes * 60))))
            guard isCurrentSession(sessionID) else {
                await IntegrationManager.shared.restoreAllStatuses()
                return
            }
        }

        // 4. Enable app blocking (FamilyControls)
        if PreferencesManager.shared.autoBlockApps {
            await enableAppBlocking()
            guard isCurrentSession(sessionID) else {
                await disableAppBlocking()
                return
            }
        }

        // 5. Write calendar busy event
        if PreferencesManager.shared.autoSyncCalendar {
            await writeCalendarBusyEvent(durationMinutes: durationMinutes)
            guard isCurrentSession(sessionID) else {
                await removeCalendarBusyEvent()
                return
            }
        }

        // 6. Start timer
        timerManager.startDuration(minutes: durationMinutes)
    }

    // MARK: - End Focus

    func endFocus(completed: Bool = false) async {
        // Prevent double-ending (e.g. manual stop + timer finish notification)
        guard let sessionStart = currentSessionStart else { return }

        // Capture session data BEFORE stop() zeroes the timer
        let sessionDuration = currentSessionDurationSeconds
        let sessionSounds = currentSessionSoundIds

        // Mark the session as ending before awaiting cleanup work so a second
        // stop request cannot record it twice.
        currentSessionStart = nil
        currentSessionDurationSeconds = 0
        currentSessionSoundIds = []
        currentSessionID = nil

        // 1. Fade out audio
        audioManager.stopAllSounds()

        // 2. Disable macOS Focus
        if PreferencesManager.shared.autoEnableFocus {
            await disableSystemFocus()
        }

        // 3. Restore IM status (independent of macOS focus mode)
        if isIMSyncEnabled {
            await IntegrationManager.shared.restoreAllStatuses()
        }

        // 4. Disable app blocking
        if PreferencesManager.shared.autoBlockApps {
            await disableAppBlocking()
        }

        // 5. Remove calendar event
        if PreferencesManager.shared.autoSyncCalendar {
            await removeCalendarBusyEvent()
        }

        // 6. Stop timer
        timerManager.stop()

        // 7. Record session with captured data
        recordFocusSession(
            startTime: sessionStart,
            plannedDurationSeconds: sessionDuration,
            soundsUsed: sessionSounds,
            completed: completed
        )

        focusState = .idle
    }

    func togglePause() {
        switch focusState {
        case .focusing(let endTime, _):
            focusState = .paused(remaining: max(0, endTime.timeIntervalSinceNow))
            timerManager.pause()
            audioManager.togglePause()
        case .paused(let remaining):
            guard remaining > 0 else {
                Task { await endFocus(completed: true) }
                return
            }
            let newEnd = Date().addingTimeInterval(remaining)
            focusState = .focusing(endTime: newEnd, duration: timerManager.totalSeconds / 60)
            timerManager.resume()
            audioManager.togglePause()
        default:
            break
        }
    }

    // MARK: - macOS Focus Mode (via Shortcuts)

    /// Checks whether the required Shortcuts are installed in ~/Library/Shortcuts/.
    /// Returns true only when BOTH FocusFlow-Enable and FocusFlow-Disable shortcuts exist.
    private var areFocusShortcutsInstalled: Bool {
        let shortcutsDir = NSString(string: "~/Library/Shortcuts").expandingTildeInPath
        let enablePath = "\(shortcutsDir)/FocusFlow-Enable.shortcut"
        let disablePath = "\(shortcutsDir)/FocusFlow-Disable.shortcut"
        return FileManager.default.fileExists(atPath: enablePath)
            && FileManager.default.fileExists(atPath: disablePath)
    }

    func dismissAutomationWarning() {
        lastAutomationWarning = nil
    }

    private func enableSystemFocus() async {
        guard areFocusShortcutsInstalled else {
            lastAutomationWarning = "快捷指令未安装：请在 Shortcuts.app 创建 FocusFlow-Enable 和 FocusFlow-Disable，详情见偏好设置。"
            print("[FocusState] Shortcut 'FocusFlow-Enable' not found — skipping system focus enable")
            return
        }

        guard let url = URL(string: "shortcuts://run-shortcut?name=FocusFlow-Enable") else { return }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(url, configuration: config) { app, error in
            if let error = error {
                print("[FocusState] Failed to trigger FocusFlow-Enable shortcut: \(error.localizedDescription)")
            } else {
                print("[FocusState] Triggered FocusFlow-Enable shortcut")
            }
        }
    }

    private func disableSystemFocus() async {
        guard areFocusShortcutsInstalled else {
            lastAutomationWarning = "快捷指令未安装：请在 Shortcuts.app 创建 FocusFlow-Enable 和 FocusFlow-Disable，详情见偏好设置。"
            print("[FocusState] Shortcut 'FocusFlow-Disable' not found — skipping system focus disable")
            return
        }

        guard let url = URL(string: "shortcuts://run-shortcut?name=FocusFlow-Disable") else { return }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(url, configuration: config) { app, error in
            if let error = error {
                print("[FocusState] Failed to trigger FocusFlow-Disable shortcut: \(error.localizedDescription)")
            } else {
                print("[FocusState] Triggered FocusFlow-Disable shortcut")
            }
        }
    }

    // MARK: - App Blocking (FamilyControls)

    private func enableAppBlocking() async {
        // FamilyControls API - Mac App Store only
        // Requires: com.apple.developer.family-controls entitlement
        // Implementation will use ManagedSettingsStore to block apps/domains:
        //
        // let store = ManagedSettingsStore()
        // store.shield.applications = blockedApps
        // store.shield.webDomains = blockedDomains
        //
        lastAutomationWarning = "应用阻断需要 App Store 版 FamilyControls 授权；当前构建将优雅跳过。"
        print("[FocusState] App blocking is unavailable in this build; skipping")
    }

    private func disableAppBlocking() async {
        // store.shield.applications = []
        // store.shield.webDomains = []
        print("[FocusState] Disabling app blocking")
    }

    // MARK: - Calendar (EventKit)

    private var lastCalendarEventID: String?
    private var lastCalendarEvent: EKEvent?
    private let eventStore = EKEventStore()

    private func writeCalendarBusyEvent(durationMinutes: Int) async {
        let authorized = await requestCalendarWriteAccessIfNeeded()

        guard authorized else {
            print("[FocusState] Calendar access denied, skipping Busy event")
            return
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            print("[FocusState] No default calendar available, skipping Busy event")
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "🔇 专注中 (FocusFlow)"
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.calendar = calendar
        event.availability = .busy
        event.notes = "由 FocusFlow 自动创建。专注结束后自动移除。"

        do {
            try eventStore.save(event, span: .thisEvent)
            lastCalendarEvent = event
            lastCalendarEventID = event.eventIdentifier
            print("[FocusState] Created Busy event in calendar for \(durationMinutes) min")
        } catch {
            print("[FocusState] Failed to create calendar event: \(error)")
        }
    }

    private func removeCalendarBusyEvent() async {
        guard let event = lastCalendarEvent ?? lastCalendarEventID.flatMap({ eventStore.event(withIdentifier: $0) }) else {
            lastCalendarEvent = nil
            lastCalendarEventID = nil
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
            lastCalendarEvent = nil
            lastCalendarEventID = nil
            print("[FocusState] Removed Busy event from calendar")
        } catch {
            print("[FocusState] Failed to remove calendar event: \(error)")
        }
    }

    private func requestCalendarWriteAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        if status == .authorized {
            return true
        }

        if #available(macOS 14.0, *) {
            if status == .fullAccess || status == .writeOnly {
                return true
            }
        }

        guard status == .notDetermined else {
            return false
        }

        if #available(macOS 14.0, *) {
            return (try? await eventStore.requestWriteOnlyAccessToEvents()) ?? false
        }

        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    print("[FocusState] Calendar access request failed: \(error)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Session Recording

    private func recordFocusSession(
        startTime: Date,
        plannedDurationSeconds: Int,
        soundsUsed: [String],
        completed: Bool
    ) {
        let endTime = Date()
        let elapsedSeconds = Int(endTime.timeIntervalSince(startTime).rounded())
        let recorded = Self.recordedDuration(
            elapsedSeconds: elapsedSeconds,
            plannedSeconds: plannedDurationSeconds,
            completed: completed
        )

        let session = FocusSession(
            startTime: startTime,
            endTime: endTime,
            durationMinutes: recorded.minutes,
            durationSeconds: recorded.seconds,
            soundsUsed: soundsUsed,
            wasCompleted: completed
        )
        StatisticsManager.shared.recordSession(session)
    }

    /// Computes the recorded duration for a session. A completed session records
    /// its full planned length; an interrupted one records elapsed wall-clock time
    /// capped at the planned length. Any non-zero duration rounds up to ≥ 1 minute.
    static func recordedDuration(
        elapsedSeconds: Int,
        plannedSeconds: Int,
        completed: Bool
    ) -> (seconds: Int, minutes: Int) {
        let seconds = completed
            ? plannedSeconds
            : min(max(0, elapsedSeconds), plannedSeconds)
        let minutes = seconds > 0 ? max(1, (seconds + 59) / 60) : 0
        return (seconds, minutes)
    }

    func normalizedSoundIds(_ soundIds: [String]) -> [String] {
        var result: [String] = []
        for soundId in soundIds where !result.contains(soundId) {
            guard SoundCatalog.allSounds.contains(where: { $0.id == soundId }) else { continue }
            result.append(soundId)
            if result.count == 3 { break }
        }
        return result
    }

    private func isCurrentSession(_ id: UUID) -> Bool {
        currentSessionID == id
    }
}
