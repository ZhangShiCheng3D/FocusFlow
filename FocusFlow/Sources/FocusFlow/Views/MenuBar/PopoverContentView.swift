import AppKit
import SwiftUI

// MARK: - Popover Content View

struct PopoverContentView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var focusManager = FocusStateManager.shared
    @ObservedObject private var odr = ODRManager.shared
    @ObservedObject private var panel = PanelStateManager.shared

    @State private var keyboardMonitor: Any?
    @State private var showCustomDurationPicker = false
    @State private var customDurationText = "90"

    var body: some View {
        VStack(spacing: 0) {
            // Header with pin button
            headerView

            // Automation warning (shortcuts not installed, etc.)
            automationWarningBanner

            // Timer selection
            timerPickerView

            // Tab picker
            tabPickerView

            // Content area
            if panel.activeTab == .sounds {
                soundGridView
            } else {
                presetsView
            }

            Divider()
                .padding(.horizontal)

            // Playback controls
            if !audioManager.activeSounds.isEmpty {
                activeSoundsView
                Divider()
                    .padding(.horizontal)
            }

            // Focus button
            focusButtonView
        }
        .padding(.bottom, 12)
        .frame(width: 320)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear { setupKeyboardHandling() }
        .onDisappear { teardownKeyboardHandling() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FocusFlow 控制面板")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("FocusFlow")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            // Pin button
            Button(action: { MenuBarController.shared.pinToFloatingWindow() }) {
                Image(systemName: "pin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("分离为悬浮窗")
            .accessibilityLabel("分离为悬浮窗")

            // Menu
            Menu {
                Button("偏好设置...") { openSettings() }
                Divider()
                Button("退出") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .accessibilityLabel("更多选项")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Warning Banner

    @ViewBuilder
    private var automationWarningBanner: some View {
        if let warning = focusManager.lastAutomationWarning {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                Text(warning)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
                Button(action: { focusManager.dismissAutomationWarning() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭提示")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.08))
        }
    }

    // MARK: - Timer Picker

    private var timerPickerView: some View {
        HStack(spacing: 8) {
            ForEach(TimerPreset.defaults) { preset in
                TimerChip(
                    minutes: preset.minutes,
                    label: preset.label,
                    isSelected: panel.selectedDuration == preset.minutes,
                    action: { panel.selectedDuration = preset.minutes }
                )
            }

            // Custom duration
            TimerChip(
                minutes: ![25, 45, 60].contains(panel.selectedDuration) ? panel.selectedDuration : 0,
                label: "自定义",
                isSelected: ![25, 45, 60].contains(panel.selectedDuration),
                action: { showCustomDurationPicker.toggle() }
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)

        // Custom duration sheet
        .popover(isPresented: $showCustomDurationPicker) {
            VStack(spacing: 12) {
                Text("自定义专注时长").font(.headline)
                HStack {
                    TextField("分钟", text: $customDurationText)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("分钟")
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach([30, 90, 120, 180], id: \.self) { mins in
                        Button("\(mins)") {
                            customDurationText = "\(mins)"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                Button("确认") {
                    if let mins = Int(customDurationText), mins > 0, mins <= 480 {
                        panel.selectedDuration = mins
                    }
                    showCustomDurationPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .frame(width: 200)
        }
    }

    private struct TimerChip: View {
        let minutes: Int
        let label: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 0) {
                    Text("\(minutes)m")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tab Picker

    private var tabPickerView: some View {
        Picker("", selection: $panel.activeTab) {
            ForEach(PanelStateManager.PanelTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityLabel("面板切换")
    }

    // MARK: - Sound Grid

    private var soundGridView: some View {
        let categorized = Dictionary(grouping: SoundCatalog.allSounds, by: { $0.category })

        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(SoundCategory.allCases, id: \.self) { category in
                    if let sounds = categorized[category], !sounds.isEmpty {
                        categorySection(category: category, sounds: sounds)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 260)
    }

    private func categorySection(category: SoundCategory, sounds: [Sound]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(sounds) { sound in
                    SoundCardView(
                        sound: sound,
                        isSelected: panel.selectedSounds.contains(sound.id),
                        volume: panel.soundVolumes[sound.id] ?? 0.7,
                        downloadProgress: odr.downloadProgress[sound.id],
                        isDownloading: odr.downloadingSoundIds.contains(sound.id),
                        onTap: { toggleSound(sound) },
                        onVolumeChange: { vol in
                            panel.soundVolumes[sound.id] = vol
                            audioManager.setVolume(for: sound.id, volume: vol)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Presets View

    private var presetsView: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Soundscape.presets) { preset in
                    PresetCardView(preset: preset, onApply: {
                        applyPreset(preset)
                    })
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 260)
    }

    private func applyPreset(_ preset: Soundscape) {
        // If already focusing, stop current sounds and restart with new mix
        let isCurrentlyPlaying = !audioManager.activeSounds.isEmpty

        if isCurrentlyPlaying {
            audioManager.stopAllSounds()
        }

        panel.selectedSounds = Set(preset.soundMix.map { $0.soundId })
        for entry in preset.soundMix {
            panel.soundVolumes[entry.soundId] = entry.volume
        }

        if isCurrentlyPlaying {
            // Restart with preset sounds
            for entry in preset.soundMix {
                if let sound = SoundCatalog.allSounds.first(where: { $0.id == entry.soundId }) {
                    Task {
                        try? await audioManager.playSound(sound, volume: entry.volume)
                    }
                }
            }
        }
    }

    // MARK: - Active Sounds

    private var activeSoundsView: some View {
        VStack(spacing: 6) {
            ForEach(Array(audioManager.activeSounds.keys), id: \.self) { soundId in
                if let sound = SoundCatalog.allSounds.first(where: { $0.id == soundId }) {
                    ActiveSoundRow(
                        sound: sound,
                        volume: Binding(
                            get: { panel.soundVolumes[soundId] ?? 0.7 },
                            set: { panel.soundVolumes[soundId] = $0; audioManager.setVolume(for: soundId, volume: $0) }
                        ),
                        onStop: {
                            audioManager.stopSound(soundId)
                            panel.selectedSounds.remove(soundId)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Focus Button

    private var focusButtonView: some View {
        VStack(spacing: 6) {
            // Countdown display when focusing
            if timerManager.isRunning {
                HStack {
                    Image(systemName: timerManager.isPaused ? "pause.circle" : "timer")
                    Text(timerManager.remainingFormatted)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))

                    Spacer()

                    Button("结束") {
                        Task { await focusManager.endFocus() }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
            }

            // Main action button
            Button(action: handleFocusButton) {
                HStack(spacing: 8) {
                    Image(systemName: focusButtonIcon)
                    Text(focusButtonLabel)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(focusButtonColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(showCustomDurationPicker)
            .accessibilityLabel(focusButtonAccessibilityLabel)
            .accessibilityHint("开始或停止专注")
        }
    }

    private var focusButtonIcon: String {
        switch focusManager.focusState {
        case .idle, .ready: return "play.fill"
        case .focusing: return "pause.fill"
        case .paused: return "play.fill"
        }
    }

    private var focusButtonLabel: String {
        switch focusManager.focusState {
        case .idle, .ready: return "开始专注"
        case .focusing: return "暂停"
        case .paused: return "继续专注"
        }
    }

    private var focusButtonColor: Color {
        switch focusManager.focusState {
        case .idle, .ready: return .accentColor
        case .focusing: return .orange
        case .paused: return .accentColor
        }
    }

    private var focusButtonAccessibilityLabel: String {
        switch focusManager.focusState {
        case .idle: return "开始 \(panel.selectedDuration) 分钟专注"
        case .ready: return "开始 \(panel.selectedDuration) 分钟专注"
        case .focusing: return "暂停专注，剩余 \(timerManager.remainingFormatted)"
        case .paused: return "继续专注，剩余 \(timerManager.remainingFormatted)"
        }
    }

    private func handleFocusButton() {
        switch focusManager.focusState {
        case .idle, .ready:
            let soundIds = Array(panel.selectedSounds)
            UserDefaults.standard.set(soundIds, forKey: "lastSoundIds")
            Task {
                await focusManager.startFocus(
                    durationMinutes: panel.selectedDuration,
                    soundIds: soundIds,
                    volumes: panel.soundVolumes
                )
            }
        case .focusing:
            focusManager.togglePause()
        case .paused:
            focusManager.togglePause()
        }
    }

    // MARK: - Sound Toggle

    private func toggleSound(_ sound: Sound) {
        if panel.selectedSounds.contains(sound.id) {
            audioManager.stopSound(sound.id)
            panel.selectedSounds.remove(sound.id)
        } else {
            guard panel.selectedSounds.count < 3 else {
                NSSound.beep()
                return
            }

            panel.selectedSounds.insert(sound.id)
            let vol = panel.soundVolumes[sound.id] ?? 0.7

            // Store soundId for this operation so we can check if user
            // toggled the sound off again during the async download.
            let soundId = sound.id

            // Single Task: download first (if needed), then play
            Task {
                if !odr.isSoundDownloaded(sound) {
                    do {
                        try await odr.downloadSound(sound)
                    } catch {
                        print("[ODR] Download failed: \(error)")
                        panel.selectedSounds.remove(soundId)
                        return
                    }
                }
                // Guard: user may have toggled this sound off during download
                guard panel.selectedSounds.contains(soundId) else { return }
                try? await audioManager.playSound(sound, volume: vol)
            }
        }
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardHandling() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // Esc — always close panel (never end focus)
                MenuBarController.shared.closePanel()
                return nil
            case 36: // Enter/Return — handled by .keyboardShortcut on the button
                return event
            case 49: // Space
                if !panel.selectedSounds.isEmpty,
                   let firstSoundId = panel.selectedSounds.first,
                   let sound = SoundCatalog.allSounds.first(where: { $0.id == firstSoundId }) {
                    toggleSound(sound)
                }
                return nil
            default:
                break
            }
            return event
        }
    }

    private func teardownKeyboardHandling() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    private func openSettings() {
        // Direct call avoids responder chain ambiguity with SwiftUI Settings scene
        SettingsWindowController.shared.show()
    }
}

// MARK: - Visual Effect Background

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
