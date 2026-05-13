import SwiftUI

// MARK: - Accessibility Utilities

/// Centralized accessibility labels for VoiceOver support.
/// Following Apple HIG guidelines for macOS accessibility.
enum A11Y {

    // MARK: - Menu Bar

    enum MenuBar {
        static let icon = "FocusFlow 菜单栏图标"
        static let idleState = "FocusFlow，未播放"
        static func playingState(remaining: String) -> String {
            "正在播放，剩余 \(remaining)"
        }
        static func pausedState(remaining: String) -> String {
            "已暂停，剩余 \(remaining)"
        }
    }

    // MARK: - Panel

    enum Panel {
        static let container = "FocusFlow 控制面板"
        static let pinButton = "分离为悬浮窗"
        static let settingsButton = "更多选项"
        static let tabPicker = "面板切换：音效 或 预设"
        static let soundsTab = "音效选择面板"
        static let presetsTab = "预设音景面板"
    }

    // MARK: - Sound Cards

    enum SoundCard {
        static func label(_ sound: Sound, isSelected: Bool, volume: Float) -> String {
            "\(sound.displayName)，\(isSelected ? "已选中，音量 \(Int(volume * 100))%" : "未选中")"
        }
        static func hint(isSelected: Bool) -> String {
            isSelected ? "双击调节音量" : "双击播放"
        }
    }

    // MARK: - Timer

    enum Timer {
        static func durationPicker(minutes: Int) -> String {
            "\(minutes) 分钟番茄钟"
        }
        static func selected(minutes: Int) -> String {
            "已选择 \(minutes) 分钟"
        }
    }

    // MARK: - Focus Button

    enum FocusButton {
        static func start(duration: Int, sounds: String) -> String {
            "开始 \(duration) 分钟专注\(sounds)"
        }
        static func pause(remaining: String) -> String {
            "暂停专注，剩余 \(remaining)"
        }
        static func resume(remaining: String) -> String {
            "继续专注，剩余 \(remaining)"
        }
        static func end() -> String {
            "结束专注"
        }
    }

    // MARK: - Settings

    enum Settings {
        static let window = "FocusFlow 偏好设置"
        static let general = "通用设置"
        static let sounds = "音效管理"
        static let integrations = "集成管理"
        static let statistics = "专注统计"
        static let about = "关于 FocusFlow"
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let wizard = "FocusFlow 设置向导"
        static let welcome = "欢迎页面：FocusFlow 是数字工位氛围构建器和防打扰效率工具"
        static let privacy = "隐私承诺：本地优先，核心数据不离机"
        static let setup = "专注模式和集成设置"
        static let done = "设置完成，开始使用 FocusFlow"
    }

    // MARK: - Volume

    enum Volume {
        static func slider(soundName: String, volume: Float) -> String {
            "\(soundName) 音量 \(Int(volume * 100))%"
        }
        static let masterVolume = "主音量"
    }

    // MARK: - Integration Status

    enum Integration {
        static func connected(_ name: String) -> String { "\(name) 已连接" }
        static func disconnected(_ name: String) -> String { "\(name) 未连接" }
        static func failed(_ name: String, reason: String) -> String { "\(name) 连接失败：\(reason)" }
    }
}

// MARK: - ViewModifier for Standard Accessibility

struct StandardAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let isHeader: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(isHeader ? .isHeader : [])
    }
}

extension View {
    func a11y(_ label: String, hint: String? = nil, isHeader: Bool = false) -> some View {
        modifier(StandardAccessibilityModifier(label: label, hint: hint, isHeader: isHeader))
    }
}
