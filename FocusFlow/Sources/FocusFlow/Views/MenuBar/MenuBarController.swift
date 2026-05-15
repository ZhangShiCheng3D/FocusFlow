import AppKit
import Combine
import SwiftUI

// MARK: - Menu Bar Controller

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var floatingWidget: FloatingWidgetWindow?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    @Published var isPanelVisible: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "FocusFlow")
            button.title = ""
            button.action = #selector(togglePanel)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            button.setAccessibilityLabel("FocusFlow 菜单栏图标")
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 520)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: PopoverContentView())

        // Close when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                guard self.isPanelVisible else { return }
                self.closePanel()
            }
        }

        setupStatusBarBindings()
        refreshStatusBar()
    }

    // MARK: - Cleanup

    func cleanup() {
        cancellables.removeAll()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        closePanel()
        unpinFromFloatingWindow()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    // MARK: - Panel Toggle

    @objc func togglePanel() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        // Double-click: quick start last session
        if event.clickCount == 2 {
            quickStartLastSession()
            return
        }

        if isPanelVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem?.button, let popover = popover else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPanelVisible = true
    }

    func closePanel() {
        popover?.performClose(nil)
        isPanelVisible = false
    }

    // MARK: - Pin to Floating Window

    func pinToFloatingWindow() {
        closePanel()
        if let existing = floatingWidget {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let widget = FloatingWidgetWindow()
        widget.show()
        floatingWidget = widget
    }

    func unpinFromFloatingWindow() {
        floatingWidget?.close()
        floatingWidget = nil
    }

    var isFloatingWidgetVisible: Bool {
        floatingWidget != nil
    }

    // MARK: - Quick Start

    private func quickStartLastSession() {
        // Guard: don't start a duplicate session on top of an active one
        let focusManager = FocusStateManager.shared
        guard !focusManager.isSessionActive else { return }

        Task {
            let prefs = PreferencesManager.shared
            let duration = prefs.defaultDuration

            // Last used sounds
            let lastSounds = UserDefaults.standard.stringArray(forKey: "lastSoundIds") ?? ["rain_light"]

            await focusManager.startFocus(
                durationMinutes: duration,
                soundIds: lastSounds
            )
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let defaultMins = PreferencesManager.shared.defaultDuration
        menu.addItem(NSMenuItem(title: "开始上次专注 (\(defaultMins)min)", action: #selector(menuQuickStart), keyEquivalent: "f"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(menuOpenSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 FocusFlow", action: #selector(menuQuit), keyEquivalent: "q"))
        guard let button = statusItem?.button else { return }
        // Use popUpContextMenu to avoid the timing problem of setting/clearing
        // statusItem?.menu around an async performClick.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func menuQuickStart() {
        quickStartLastSession()
    }

    @objc private func menuOpenSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status Bar Update

    private func setupStatusBarBindings() {
        let timer = TimerManager.shared
        let audio = AudioManager.shared
        let prefs = PreferencesManager.shared

        let triggers: [AnyPublisher<Void, Never>] = [
            timer.$remainingSeconds.map { _ in () }.eraseToAnyPublisher(),
            timer.$totalSeconds.map { _ in () }.eraseToAnyPublisher(),
            timer.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            timer.$isPaused.map { _ in () }.eraseToAnyPublisher(),
            audio.$playbackState.map { _ in () }.eraseToAnyPublisher(),
            audio.$activeSounds.map { _ in () }.eraseToAnyPublisher(),
            prefs.$countdownDisplayMode.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(triggers)
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                Task { @MainActor in
                    self?.refreshStatusBar()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshStatusBar() {
        let timer = TimerManager.shared
        let audio = AudioManager.shared
        updateStatusBar(
            timerText: timer.statusBarText,
            isPlaying: audio.playbackState == .playing,
            progress: min(1, max(0, timer.progress))
        )
    }

    func updateStatusBar(timerText: String, isPlaying: Bool, progress: Double) {
        guard let button = statusItem?.button else { return }

        guard !timerText.isEmpty else {
            button.title = ""
            button.image = NSImage(
                systemSymbolName: isPlaying ? "headphones" : "headphones.circle",
                accessibilityDescription: "FocusFlow"
            )
            button.setAccessibilityValue(isPlaying ? "正在播放环境音" : "FocusFlow，未播放")
            return
        }

        switch PreferencesManager.shared.countdownDisplayMode {
        case .full:
            button.title = timerText
            button.image = nil
        case .compact:
            let minutes = (TimerManager.shared.remainingSeconds + 59) / 60
            button.title = "\(minutes)m"
            button.image = nil
        case .pie:
            button.title = ""
            button.image = ProgressPieImage(progress: progress, isPlaying: isPlaying)
        case .widget:
            button.title = ""
            button.image = NSImage(systemSymbolName: isPlaying ? "headphones" : "headphones.circle",
                                   accessibilityDescription: "FocusFlow")
        }

        button.setAccessibilityValue(
            isPlaying ? "正在播放，剩余 \(timerText)" : "已暂停，剩余 \(timerText)"
        )
    }
}

// MARK: - Progress Pie Image

func ProgressPieImage(progress: Double, isPlaying: Bool) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { _ in
        // Background circle
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(ovalIn: rect)
        NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 2
        path.stroke()

        // Progress arc
        if isPlaying && progress > 0 {
            let center = NSPoint(x: size.width / 2, y: size.height / 2)
            let radius = rect.width / 2
            let startAngle: CGFloat = -90
            let endAngle: CGFloat = startAngle + CGFloat(progress) * 360

            let arcPath = NSBezierPath()
            arcPath.appendArc(withCenter: center, radius: radius,
                              startAngle: startAngle, endAngle: endAngle, clockwise: true)
            NSColor.controlTextColor.setStroke()
            arcPath.lineWidth = 2
            arcPath.lineCapStyle = .round
            arcPath.stroke()
        }

        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - Floating Widget Window

final class FloatingWidgetWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 420),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // Rounded corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 16
        self.contentView?.layer?.masksToBounds = true

        // PopoverContentView provides its own visual effect background.
        // We add only the hosting view — no duplicate NSVisualEffectView.
        guard let contentView = self.contentView else { return }
        let hostingView = NSHostingView(rootView: PopoverContentView())
        hostingView.frame = contentView.bounds
        hostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(hostingView)

        // Position near menu bar
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 300
            let y = screenFrame.maxY - 440
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func show() {
        self.makeKeyAndOrderFront(nil)
    }
}
