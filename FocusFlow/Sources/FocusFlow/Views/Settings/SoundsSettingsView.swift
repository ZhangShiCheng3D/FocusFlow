import SwiftUI

// MARK: - Sounds Settings

struct SoundsSettingsView: View {
    @ObservedObject private var odr = ODRManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader("音效管理", icon: "speaker.wave.2")

                // Download status
                VStack(alignment: .leading, spacing: 8) {
                    Text("下载的音效：\(downloadedCount) / \(SoundCatalog.allSounds.count)")
                        .font(.system(size: 13))

                    ProgressView(
                        value: Double(downloadedCount),
                        total: Double(SoundCatalog.allSounds.count)
                    )
                    .tint(.accentColor)
                    .accessibilityLabel("已下载 \(downloadedCount) 个音效，共 \(SoundCatalog.allSounds.count) 个")

                    Text("缓存大小: \(formattedCacheSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(10)

                // Actions
                HStack(spacing: 12) {
                    Button("下载全部音效") {
                        Task { await odr.preloadAvailableRemoteSounds() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("清除缓存") {
                        try? odr.clearCache()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .accessibilityHint("下载或清除音效缓存")

                Divider()

                // Sound list
                SettingsSectionHeader("音效列表", icon: "list.bullet")

                ForEach(SoundCategory.allCases, id: \.self) { category in
                    let sounds = SoundCatalog.allSounds.filter { $0.category == category }
                    if !sounds.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)

                            ForEach(sounds) { sound in
                                SoundStatusRow(
                                    sound: sound,
                                    isDownloaded: odr.isSoundDownloaded(sound)
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var downloadedCount: Int {
        SoundCatalog.allSounds.filter { odr.isSoundDownloaded($0) }.count
    }

    private var formattedCacheSize: String {
        let bytes = odr.cacheSize()
        if bytes < 1024 * 1024 {
            return "\(bytes / 1024) KB"
        }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

struct SoundStatusRow: View {
    let sound: Sound
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sound.icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 18)

            Text(sound.displayName)
                .font(.system(size: 12))

            if !sound.isFree {
                Text("Pro")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.7))
                    .cornerRadius(3)
            }

            Spacer()

            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                .font(.system(size: 12))
                .foregroundColor(isDownloaded ? .green : .secondary)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .accessibilityLabel("\(sound.displayName)，\(isDownloaded ? "已下载" : "未下载")")
    }
}
