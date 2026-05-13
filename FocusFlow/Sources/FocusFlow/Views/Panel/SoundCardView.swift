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
        VStack(spacing: 0) {
            Button(action: onTap) {
                VStack(spacing: 2) {
                    ZStack {
                        Image(systemName: sound.icon)
                            .font(.system(size: 22))
                            .foregroundColor(isSelected ? .accentColor : .secondary)

                        // Download progress ring
                        if isDownloading {
                            ProgressRing(progress: downloadProgress ?? 0)
                                .frame(width: 28, height: 28)
                        }

                        // Selected indicator
                        if isSelected {
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                .frame(width: 32, height: 32)
                        }

                        // Pro badge
                        if !sound.isFree {
                            Text("Pro")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.8))
                                .cornerRadius(3)
                                .offset(x: 14, y: -14)
                        }
                    }

                    Text(sound.displayName)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(sound.displayName)，\(isSelected ? "已选中，音量 \(Int(volume * 100))%" : "未选中")")
            .accessibilityHint(isSelected ? "在下方已激活音效中调节音量" : "双击播放")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        Circle()
            .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
            .overlay(
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
        HStack(spacing: 8) {
            Image(systemName: sound.icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text(sound.displayName)
                .font(.system(size: 12))
                .lineLimit(1)

            Slider(value: $volume, in: 0...1.0) { editing in
                if !editing {
                    // Volume change committed
                }
            }
            .frame(width: 100)
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
        .padding(.vertical, 2)
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
                    Text(soundNames)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 16))
                    .foregroundColor(isHovering ? .accentColor : .secondary)
            }
            .padding(10)
            .background(isHovering ? Color.accentColor.opacity(0.06) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
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
