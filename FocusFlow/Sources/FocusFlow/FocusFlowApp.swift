import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 580, height: 440)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var isTerminatingAfterFocusCleanup = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        MenuBarController.shared.setup()

        // Show onboarding if first launch
        let prefs = PreferencesManager.shared
        if !prefs.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showOnboarding()
            }
        }

        // Settings handled natively by SwiftUI Settings scene (Cmd+,)
        // SettingsWindowController available for programmatic access from popover menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Suspend audio engine
        AudioManager.shared.stopAllSounds()
        AudioManager.shared.suspendEngineIfIdle()

        // Clean up event monitors to prevent leaks
        MenuBarController.shared.cleanup()

        // Invalidate URLSession to release delegate
        ODRManager.shared.invalidateSession()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard FocusStateManager.shared.isSessionActive, !isTerminatingAfterFocusCleanup else {
            return .terminateNow
        }

        isTerminatingAfterFocusCleanup = true
        Task { @MainActor in
            await FocusStateManager.shared.endFocus(completed: false)
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Double-click on dock (if shown) toggles panel
        MenuBarController.shared.togglePanel()
        return true
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 FocusFlow"
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
    }

    // MARK: - Settings

    @objc func showSettingsWindow() {
        SettingsWindowController.shared.show()
    }
}

// MARK: - Settings Menu Support

extension NSApplication {
    @objc func showSettingsWindow(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }
}
