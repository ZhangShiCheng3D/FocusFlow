import Foundation
import Combine

// MARK: - Panel State Manager

/// Shared state between the popover and the floating (pinned) window.
/// Ensures selected sounds, volumes, and timer duration are consistent
/// across both the NSPopover and the detached NSPanel.

@MainActor
final class PanelStateManager: ObservableObject {
    static let shared = PanelStateManager()

    @Published var selectedSounds: Set<String> = []
    @Published var soundVolumes: [String: Float] = [:]
    @Published var selectedDuration: Int = 25
    @Published var activeTab: PanelTab = .sounds

    enum PanelTab: String, CaseIterable {
        case sounds = "音效"
        case presets = "预设"
    }

    private init() {}
}
