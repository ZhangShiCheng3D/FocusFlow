import SwiftUI

// MARK: - Integrations Settings

struct IntegrationsSettingsView: View {
    @ObservedObject private var integrationManager = IntegrationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader("IM 状态同步", icon: "link")

                Text("专注时自动将您的在线状态设置为「专注中」。\n授权失败时静默跳过，不弹窗打断心流。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Slack
                IntegrationCard(
                    icon: "slack",
                    name: "Slack",
                    description: "最适合中小团队。权限控制宽松，广泛使用。",
                    status: integrationManager.integrationStatuses[.slack] ?? .notConfigured,
                    onConnect: { Task { await integrationManager.authorize(.slack) } },
                    onDisconnect: { integrationManager.disconnect(.slack) }
                )

                // Discord
                IntegrationCard(
                    icon: "discord",
                    name: "Discord",
                    description: "适合社区和游戏开发团队。",
                    status: integrationManager.integrationStatuses[.discord] ?? .notConfigured,
                    onConnect: { Task { await integrationManager.authorize(.discord) } },
                    onDisconnect: { integrationManager.disconnect(.discord) }
                )

                // Teams
                IntegrationCard(
                    icon: "teams",
                    name: "Microsoft Teams",
                    description: "实验性功能。大型企业可能被 IT 管理员策略拦截。适合中小企业。",
                    status: integrationManager.integrationStatuses[.teams] ?? .notConfigured,
                    onConnect: { Task { await integrationManager.authorize(.teams) } },
                    onDisconnect: { integrationManager.disconnect(.teams) }
                )
                .overlay(alignment: .topTrailing) {
                    Text("Beta")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                        .offset(x: 4, y: -4)
                }
            }
            .padding(20)
        }
    }
}

struct IntegrationCard: View {
    let icon: String
    let name: String
    let description: String
    let status: IntegrationStatus
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            IntegrationLogo(icon: icon, statusColor: statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundColor(statusColor)
            }

            Spacer()

            switch status {
            case .notConfigured:
                Button("连接") { onConnect() }
                    .buttonStyle(.borderedProminent)
                    .tint(.ffPrimary)
                    .controlSize(.small)
                    .accessibilityHint("授权 \(name) 连接")
            case .authorized:
                Button("断开") { onDisconnect() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .accessibilityHint("断开 \(name) 连接")
            case .failed:
                Button("重试") { onConnect() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("重试 \(name) 授权")
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color.ffSurface.opacity(0.3))
        .cornerRadius(DesignTokens.radiusLG)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)：\(statusText)")
    }

    private var statusText: String {
        switch status {
        case .notConfigured: return "未连接"
        case .authorized: return "已连接"
        case .failed(let reason): return reason.description
        }
    }

    private var statusColor: Color {
        switch status {
        case .notConfigured: return .secondary
        case .authorized: return .ffSuccess
        case .failed(let reason):
            if case .adminConsentRequired = reason { return .orange }
            return .red
        }
    }
}

private struct IntegrationLogo: View {
    let icon: String
    let statusColor: Color

    var body: some View {
        Text(initial)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(Circle().fill(statusColor.opacity(0.8)))
            .frame(width: 36)
            .accessibilityHidden(true)
    }

    private var initial: String {
        switch icon {
        case "slack": return "S"
        case "discord": return "D"
        case "teams": return "T"
        default: return String(icon.prefix(1)).uppercased()
        }
    }
}
