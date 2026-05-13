import SwiftUI

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Launch
                Group {
                    SettingsSectionHeader("启动", icon: "power")

                    Toggle("登录时自动启动", isOn: $prefs.launchAtLogin)
                        .accessibilityHint("macOS 登录时自动启动 FocusFlow")
                }

                Divider()

                // Default Duration
                Group {
                    SettingsSectionHeader("专注时长", icon: "timer")

                    HStack(spacing: 12) {
                        ForEach([25, 45, 60], id: \.self) { mins in
                            Button("\(mins) 分钟") {
                                prefs.defaultDuration = mins
                            }
                            .buttonStyle(.bordered)
                            .tint(prefs.defaultDuration == mins ? .accentColor : .secondary)
                        }
                    }
                    .accessibilityLabel("默认专注时长：\(prefs.defaultDuration) 分钟")
                }

                Divider()

                // Countdown Display
                Group {
                    SettingsSectionHeader("菜单栏倒计时", icon: "rectangle.topthird.inset")

                    Picker("显示模式", selection: $prefs.countdownDisplayMode) {
                        Text("完整 HH:MM").tag(PreferencesManager.CountdownDisplayMode.full)
                        Text("紧凑 25m").tag(PreferencesManager.CountdownDisplayMode.compact)
                        Text("饼图").tag(PreferencesManager.CountdownDisplayMode.pie)
                        Text("悬浮窗").tag(PreferencesManager.CountdownDisplayMode.widget)
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityLabel("菜单栏倒计时显示模式")

                    Text(displayModeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Automations
                Group {
                    SettingsSectionHeader("自动化", icon: "gearshape.2")

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("自动开启 macOS 专注模式", isOn: $prefs.autoEnableFocus)
                            .accessibilityHint("专注开始时自动启用系统专注模式屏蔽通知")

                        Text("仅用于开关专注模式，不读取通知内容")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("IM 状态同步 (Slack/Discord/Teams)", isOn: $prefs.isIMSyncEnabled)
                            .accessibilityHint("专注时自动设置即时通讯在线状态")

                        Text("授权失败时静默跳过，不弹窗打断心流")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("自动阻断干扰应用 (App Store 版)", isOn: $prefs.autoBlockApps)
                            .accessibilityHint("App Store 版获得授权后，可在专注期间屏蔽指定应用和网站")

                        Text("当前构建会优雅跳过；启用 FamilyControls 后不上传使用数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("自动写入日历 Busy 事件", isOn: $prefs.autoSyncCalendar)
                            .accessibilityHint("专注时段在系统日历中标记为忙碌")

                        Text("仅写入 Busy 时段，不读取日程详情")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }

                Divider()

                // Hotkey
                Group {
                    SettingsSectionHeader("快捷键", icon: "command")

                    Toggle("启用全局快捷键", isOn: $prefs.useGlobalHotkey)

                    if prefs.useGlobalHotkey {
                        HStack {
                            Text("快捷键组合:")
                            TextField("点击录制快捷键", text: $prefs.hotkeyCombo)
                                .frame(width: 120)
                            Button("清除") { prefs.hotkeyCombo = "" }
                        }
                        .padding(.leading, 20)

                        Text("若与其他 App 冲突，请更换组合键")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    Text("提示：双击菜单栏图标可快速开始上次配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Slack branding
                Toggle("在 Slack 状态中显示 FocusFlow 名称（有助于团队内传播）", isOn: $prefs.showSlackBranding)
                    .font(.system(size: 13))
            }
            .padding(20)
        }
    }

    private var displayModeDescription: String {
        switch prefs.countdownDisplayMode {
        case .full: return "显示完整时间，如 25:00。适合菜单栏空间充裕时使用。"
        case .compact: return "仅显示分钟数，如 25m。适合刘海屏或菜单栏拥挤时使用。"
        case .pie: return "饼图小图标动态填满。最省空间，适合菜单栏极度拥挤时。"
        case .widget: return "独立悬浮窗显示，不受菜单栏空间限制。适合全屏工作。"
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    let icon: String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
