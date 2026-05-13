import SwiftUI

// MARK: - Settings Window

final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        // Close any empty Settings window created by the SwiftUI Settings scene
        // to prevent two settings windows from appearing simultaneously.
        for win in NSApp.windows where win.title == "FocusFlow 偏好设置" && win !== window {
            win.close()
        }

        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 440),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "FocusFlow 偏好设置"
            window?.contentView = NSHostingView(rootView: SettingsView())
            window?.center()
            window?.isReleasedWhenClosed = false
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "通用"
        case sounds = "音效"
        case integrations = "集成"
        case statistics = "统计"
        case about = "关于"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack {
                            Image(systemName: tab.icon)
                                .frame(width: 20)
                            Text(tab.rawValue)
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(width: 140)
            .background(Color.secondary.opacity(0.05))

            Divider()

            // Content
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 580, height: 440)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FocusFlow 偏好设置")
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .general: GeneralSettingsView()
        case .sounds: SoundsSettingsView()
        case .integrations: IntegrationsSettingsView()
        case .statistics: StatisticsSettingsView()
        case .about: AboutSettingsView()
        }
    }
}

extension SettingsView.SettingsTab {
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .sounds: return "speaker.wave.2"
        case .integrations: return "link"
        case .statistics: return "chart.bar"
        case .about: return "info.circle"
        }
    }
}
