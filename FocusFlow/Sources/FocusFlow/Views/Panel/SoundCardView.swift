import SwiftUI

// MARK: - Sound Card View

struct SoundCardView: View {
    let sound: Sound
    let isSelected: Bool
    let volume: Float
    let downloadProgress: Double?
    let isDownloading: Bool
    let onTap: () -> Void
    let onVolumeChange: (Float) -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: sound.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .ffPrimary : .secondary)

                    // Download progress ring
                    if isDownloading {
                        ProgressRing(progress: downloadProgress ?? 0)
                            .frame(width: 26, height: 26)
                    }

                    // Selected ring
                    if isSelected {
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                            .strokeBorder(Color.ffPrimary, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    // Pro dot (subtle)
                    if !sound.isFree {
                        Circle()
                            .fill(Color.ffPrimary.opacity(0.7))
                            .frame(width: 5, height: 5)
                            .offset(x: 15, y: -15)
                    }
                }

                Text(sound.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .ffTextPrimary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSM)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .fill(isSelected ? Color.ffPrimary.opacity(0.10) : Color.ffSurface.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                .stroke(
                    isSelected ? Color.ffPrimary.opacity(0.3) : Color.secondary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .accessibilityLabel("\(sound.displayName)，\(isSelected ? "已选中，音量 \(Int(volume * 100))%" : "未选中")")
        .accessibilityHint(isSelected ? "在下方已激活音效中调节音量" : "双击播放")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        Circle()
            .stroke(Color.secondary.opacity(0.15), lineWidth: 2)
            .overlay(
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.ffPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
            )
    }
}

// MARK: - Active Sound Row

struct ActiveSoundRow: View {
    let sound: Sound
    @Binding var volume: Float
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: sound.icon)
                .font(.system(size: 14))
                .foregroundColor(.ffPrimary)
                .accessibilityHidden(true)

            Text(sound.displayName)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.ffTextPrimary)

            Slider(value: $volume, in: 0...1.0) { _ in }
                .frame(width: 90)
                .tint(.ffPrimary)
                .accessibilityLabel("\(sound.displayName) 音量")
                .accessibilityValue("\(Int(volume * 100))%")

            Text("\(Int(volume * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30)

            Button(action: onStop) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("停止 \(sound.displayName)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, DesignTokens.spacingSM)
        .background(Color.ffSurface.opacity(0.3))
        .cornerRadius(DesignTokens.radiusSM)
    }
}

// MARK: - Preset Card View

struct PresetCardView: View {
    let preset: Soundscape
    let onApply: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onApply) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.ffTextPrimary)
                    Text(soundNames)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 16))
                    .foregroundColor(isHovering ? .ffPrimary : .secondary)
            }
            .padding(DesignTokens.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .fill(isHovering ? Color.ffPrimary.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(preset.name) 预设，包含 \(soundNames)")
        .accessibilityHint("双击加载此预设")
    }

    private var soundNames: String {
        preset.soundMix.compactMap { entry in
            SoundCatalog.allSounds.first(where: { $0.id == entry.soundId })?.displayName
        }.joined(separator: " + ")
    }
}
