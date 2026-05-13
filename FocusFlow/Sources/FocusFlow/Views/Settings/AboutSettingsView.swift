import SwiftUI

// MARK: - About View

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("FocusFlow")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("数字工位氛围构建器 · 防打扰效率工具")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Privacy statement
            VStack(alignment: .leading, spacing: 8) {
                Label("Local-First 架构", systemImage: "checkmark.shield")
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                Label("核心数据仅存储在您的设备本地", systemImage: "internaldrive")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Label("无后端数据库，无用户追踪", systemImage: "eye.slash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Label("OAuth Token 仅保存在本机钥匙串", systemImage: "key.horizontal")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(10)

            Divider()
                .padding(.horizontal, 40)

            Text("© 2026 FocusFlow. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let privacyURL = URL(string: "https://focusflow.app/privacy") {
                Link("隐私政策", destination: privacyURL)
                    .font(.caption2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
