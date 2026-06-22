import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Global Hotkey

/// A global hotkey combination (e.g. "⌘⌥F") parsed into a Carbon virtual key
/// code + modifier mask, ready for `RegisterEventHotKey`. Returns nil for any
/// string that lacks at least one modifier and a recognizable A–Z / 0–9 key.
struct HotKeyCombo: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    init?(string: String) {
        var mods: UInt32 = 0
        var keyChar: Character?
        for ch in string {
            switch ch {
            case "⌘": mods |= UInt32(cmdKey)
            case "⌥": mods |= UInt32(optionKey)
            case "⌃": mods |= UInt32(controlKey)
            case "⇧": mods |= UInt32(shiftKey)
            case " ": continue
            default: keyChar = ch
            }
        }
        guard mods != 0, let key = keyChar,
              let code = Self.keyCode(for: key) else { return nil }
        self.keyCode = code
        self.carbonModifiers = mods
    }

    private static func keyCode(for ch: Character) -> UInt32? {
        let map: [Character: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9
        ]
        return map[Character(ch.uppercased())].map(UInt32.init)
    }
}

// Four-char-code 'FFLW' — identifies our hotkey in the Carbon event stream.
// File-level so the nonisolated C event callback can read it without crossing
// an actor boundary.
private let kFocusFlowHotKeySignature: OSType = 0x46_46_4C_57

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// Re-registers the global hotkey to match the given preferences. Safe to call
    /// repeatedly — it clears any previous registration first. A disabled toggle or
    /// an unparseable combo simply leaves no hotkey registered.
    func apply(enabled: Bool, combo: String) {
        unregisterHotkey()
        guard enabled, let parsed = HotKeyCombo(string: combo) else { return }

        installEventHandlerIfNeeded()
        let id = EventHotKeyID(signature: kFocusFlowHotKeySignature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            parsed.keyCode, parsed.carbonModifiers, id,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            print("[Hotkey] RegisterEventHotKey failed: \(status)")
        }
    }

    func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // The callback is a bare C function pointer (no captures); it bounces back
        // onto the main actor to run the (actor-isolated) focus start.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event = event else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hkID
                )
                guard hkID.signature == kFocusFlowHotKeySignature else { return noErr }
                Task { @MainActor in GlobalHotkeyManager.shared.handleHotkey() }
                return noErr
            },
            1, &spec, nil, &eventHandler
        )
    }

    func handleHotkey() {
        guard !FocusStateManager.shared.isSessionActive else { return }

        let prefs = PreferencesManager.shared
        let lastSounds = UserDefaults.standard.stringArray(forKey: "lastSoundIds") ?? ["rain_light"]

        Task {
            await FocusStateManager.shared.startFocus(
                durationMinutes: prefs.defaultDuration,
                soundIds: lastSounds
            )
        }
    }
}

// MARK: - Hotkey Recorder Field

/// A SwiftUI control that records a global hotkey: click it, press a modified
/// key combination, and it stores the canonical symbol string (e.g. "⌘⌥F").
struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var combo: String

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let button = HotkeyRecorderButton()
        button.onCapture = { combo = $0 }
        button.combo = combo
        return button
    }

    func updateNSView(_ nsView: HotkeyRecorderButton, context: Context) {
        nsView.combo = combo
    }
}

final class HotkeyRecorderButton: NSButton {
    var onCapture: ((String) -> Void)?
    var combo: String = "" {
        didSet { if !isRecording { refreshTitle() } }
    }

    private var isRecording = false
    private var monitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func refreshTitle() {
        title = combo.isEmpty ? "点击录制快捷键" : combo
    }

    @objc private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = "请按下组合键…"
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.capture(event)
            return nil
        }
    }

    private func capture(_ event: NSEvent) {
        let flags = event.modifierFlags
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }

        // Require at least one modifier + a letter/digit, otherwise keep listening.
        guard !symbols.isEmpty,
              let first = event.charactersIgnoringModifiers?.uppercased().first,
              first.isLetter || first.isNumber else {
            return
        }

        let result = symbols + String(first)
        endRecording()
        combo = result
        onCapture?(result)
    }

    private func endRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        refreshTitle()
    }
}
