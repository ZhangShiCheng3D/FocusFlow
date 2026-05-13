import SwiftUI
import AppKit

// MARK: - Keyboard Navigation Utilities

enum KeyboardNavigation {
    /// Standard keyboard shortcut set for the popover panel
    enum PopoverShortcut: CaseIterable {
        case tab
        case shiftTab
        case space
        case enter
        case escape
        case upArrow
        case downArrow
        case leftArrow
        case rightArrow

        var keyCode: UInt16 {
            switch self {
            case .tab: return 48
            case .space: return 49
            case .escape: return 53
            case .enter: return 36
            case .upArrow: return 126
            case .downArrow: return 125
            case .leftArrow: return 123
            case .rightArrow: return 124
            case .shiftTab: return 48 // Tab with shift modifier
            }
        }

        var requiresShift: Bool {
            self == .shiftTab
        }
    }
}

// MARK: - Global Hotkey Manager

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    private var eventMonitor: Any?

    private init() {}

    func registerHotkey(combo: String) {
        unregisterHotkey()

        // Parse combo (e.g., "⌘⌥F")
        // Full implementation requires Carbon Event Manager or MASShortcut
        // For now, we use NSEvent monitoring as fallback
        print("[Hotkey] Registering: \(combo)")
    }

    func unregisterHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitor = nil
    }

    func handleHotkey() {
        Task {
            guard !FocusStateManager.shared.isSessionActive else { return }

            let prefs = PreferencesManager.shared
            let duration = prefs.defaultDuration
            let lastSounds = UserDefaults.standard.stringArray(forKey: "lastSoundIds") ?? ["rain_light"]

            await FocusStateManager.shared.startFocus(
                durationMinutes: duration,
                soundIds: lastSounds
            )
        }
    }
}

// MARK: - View Extension for Keyboard Handling

extension View {
    func onPopoverKeyPress(perform action: @escaping (NSEvent) -> NSEvent?) -> some View {
        self.background(KeyEventView(onEvent: action))
    }
}

struct KeyEventView: NSViewRepresentable {
    let onEvent: (NSEvent) -> NSEvent?

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onEvent = onEvent
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class KeyCaptureView: NSView {
    var onEvent: ((NSEvent) -> NSEvent?)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onEvent?(event) != nil {
            // Event was handled
        } else {
            super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool { true }
}
