import AppKit
import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var currentPage: OnboardingPage = .welcome

    enum OnboardingPage: Int, CaseIterable {
        case welcome = 0
        case privacy = 1
        case focus = 2
        case integrations = 3
        case done = 4
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                    Circle()
                        .fill(currentPage.rawValue >= page.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 20)

            // Page content
            currentPageView
                .frame(height: 320)

            // Bottom buttons
            HStack {
                if currentPage.rawValue > 0 && currentPage != .done {
                    Button("上一步") {
                        movePage(by: -1)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                } else {
                    Spacer()
                }

                Spacer()

                if currentPage != .done {
                    Button("下一步") {
                        movePage(by: 1)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("开始使用 FocusFlow") {
                        PreferencesManager.shared.hasCompletedOnboarding = true
                        dismiss()
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 440)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FocusFlow 设置向导")
    }

    private func movePage(by delta: Int) {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + delta) else { return }
        withAnimation { currentPage = next }
    }

    @ViewBuilder
    private var currentPageView: some View {
        switch currentPage {
        case .welcome: welcomePage
        case .privacy: privacyPage
        case .focus: focusPage
        case .integrations: integrationsPage
        case .done: donePage
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("欢迎使用 FocusFlow")
                .font(.title)
                .fontWeight(.bold)

            Text("数字工位氛围构建器 · 防打扰效率工具")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("一键构建深度工作环境：\n环境音 + 专注模式 + IM 状态同步 + 应用阻断")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding(32)
        .accessibilityLabel("欢迎页面：FocusFlow 是数字工位氛围构建器和防打扰效率工具")
    }

    // MARK: - Privacy Page (v4.0 Shield)

    private var privacyPage: some View {
        VStack(spacing: 16) {
            // Shield icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "shield.checkered")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }

            Text("您的数据，留在您的设备上")
                .font(.title3)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 10) {
                PrivacyBullet(icon: "iphone.and.arrow.forward", text: "所有核心数据仅存储在您的设备本地")
                PrivacyBullet(icon: "server.slash", text: "无后端数据库，无用户账号体系，无行为追踪")
                PrivacyBullet(icon: "key.horizontal", text: "OAuth Token 仅保存于本机钥匙串，代理服务不长期存储")
                PrivacyBullet(icon: "mic.slash", text: "环境音全部本地处理，麦克风永不激活")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(24)
        .accessibilityLabel("隐私承诺：本地优先，核心数据不离机")
    }

    private struct PrivacyBullet: View {
        let icon: String
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .frame(width: 20)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
        }
    }

    // MARK: - Focus Page

    private var focusPage: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundColor(.indigo)

            Text("自动化专注模式")
                .font(.title3)
                .fontWeight(.bold)

            Text("FocusFlow 可以在您开始专注时\n自动开启 macOS 专注模式")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("是否允许控制专注模式？")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $prefs.autoEnableFocus)
                        .toggleStyle(.switch)
                        .accessibilityLabel("允许控制专注模式")
                }

                Text("仅用于开关系统专注模式，不读取通知内容")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("可在设置中随时更改")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(10)
        }
        .padding(24)
        .accessibilityLabel("自动化专注模式设置")
    }

    // MARK: - Integrations Page

    private var integrationsPage: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue)

            Text("连接工作工具")
                .font(.title3)
                .fontWeight(.bold)

            Text("可选连接 Slack、Discord 或 Teams\n专注时自动设置状态")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                IntegrationRow(icon: "S", name: "Slack", action: {
                    Task { await IntegrationManager.shared.authorize(.slack) }
                })
                IntegrationRow(icon: "D", name: "Discord", action: {
                    Task { await IntegrationManager.shared.authorize(.discord) }
                })
                IntegrationRow(icon: "T", name: "Teams (Beta)", action: {
                    Task { await IntegrationManager.shared.authorize(.teams) }
                })
            }

            Text("全部可选，现在跳过不影响使用")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .accessibilityLabel("连接工作工具：Slack、Discord、Teams")
    }

    private struct IntegrationRow: View {
        let icon: String
        let name: String
        let action: () -> Void

        var body: some View {
            HStack {
                Text(icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.accentColor.opacity(0.75)))

                Text(name)
                    .font(.system(size: 13))
                Spacer()
                Button("连接") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
            .accessibilityLabel("连接 \(name)")
            .accessibilityHint("双击进行授权")
        }
    }

    // MARK: - Done Page

    private var donePage: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("一切就绪！")
                .font(.title)
                .fontWeight(.bold)

            Text("点击菜单栏耳机图标\n开始您的第一次深度工作")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Label("双击图标快速开始上次配置", systemImage: "hand.tap")
                Label("Tab/空格键纯键盘操作", systemImage: "keyboard")
                Label("Esc 随时关闭面板", systemImage: "escape")
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .padding(32)
        .accessibilityLabel("设置完成，开始使用 FocusFlow")
    }
}
