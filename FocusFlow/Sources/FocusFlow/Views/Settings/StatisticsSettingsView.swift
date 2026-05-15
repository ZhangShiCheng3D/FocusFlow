import SwiftUI

// MARK: - Statistics View

struct StatisticsSettingsView: View {
    @ObservedObject private var stats = StatisticsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader("专注统计", icon: "chart.bar")

                // Summary cards
                HStack(spacing: 12) {
                    StatCard(title: "今日", minutes: stats.todayTotalMinutes, color: .ffPrimary)
                    StatCard(title: "本周", minutes: stats.weekTotalMinutes, color: .ffSuccess)
                    StatCard(title: "本月", minutes: stats.monthTotalMinutes, color: .orange)
                }

                Divider()

                // Heatmap
                SettingsSectionHeader("最近 30 天", icon: "calendar")

                HeatmapView(sessions: stats.sessionsForLastDays(30))
                    .frame(height: 140)

                Divider()

                // Recent sessions
                SettingsSectionHeader("最近专注记录", icon: "list.bullet")

                if stats.sessions.isEmpty {
                    Text("还没有专注记录，开始第一次专注吧！")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(stats.sessions.suffix(10).reversed()) { session in
                        SessionRow(session: session)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct StatCard: View {
    let title: String
    let minutes: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(formattedMinutes)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(formattedMinutes)")
    }

    private var formattedMinutes: String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.durationMinutes >= 60 ?
                     "\(session.durationMinutes / 60)h \(session.durationMinutes % 60)m" :
                     "\(session.durationMinutes)m")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                Text(session.soundsUsed.compactMap { id in
                    SoundCatalog.allSounds.first(where: { $0.id == id })?.displayName
                }.joined(separator: ", "))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Text(dateFormatter.string(from: session.startTime))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if session.wasCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.ffSuccess)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(formattedDuration)，\(dateFormatter.string(from: session.startTime))")
    }

    private var formattedDuration: String {
        "\(session.durationMinutes) 分钟"
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }
}

// MARK: - Heatmap

struct HeatmapView: View {
    let sessions: [Date: Int]  // date -> minutes

    var body: some View {
        let sortedDates = sessions.keys.sorted()
        let maxMinutes = sessions.values.max() ?? 1

        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(14), spacing: 3), count: 7),
            spacing: 3
        ) {
            ForEach(sortedDates, id: \.self) { date in
                let minutes = sessions[date] ?? 0
                let intensity = CGFloat(minutes) / CGFloat(max(maxMinutes, 1))

                RoundedRectangle(cornerRadius: 2)
                    .fill(heatmapColor(intensity: intensity))
                    .frame(width: 14, height: 14)
                    .help("\(dateFormatter.string(from: date)): \(minutes)m")
                    .accessibilityLabel("\(dateFormatter.string(from: date))：\(minutes) 分钟")
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f
    }

    private func heatmapColor(intensity: CGFloat) -> Color {
        if intensity <= 0 { return Color.secondary.opacity(0.1) }
        return Color.ffPrimary.opacity(0.2 + intensity * 0.8)
    }
}
