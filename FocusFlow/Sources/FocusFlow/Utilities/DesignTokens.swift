import SwiftUI

// MARK: - Design Tokens — "Calm Focus"
// Generated via Stitch design system. See stitch-design/ for full mockups.

enum DesignTokens {
    // MARK: Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacing2XL: CGFloat = 24

    // MARK: Radius
    static let radiusSM: CGFloat = 6
    static let radiusMD: CGFloat = 8
    static let radiusLG: CGFloat = 12
    static let radiusFull: CGFloat = 9999

    // MARK: Hit Targets
    static let minTapTarget: CGFloat = 28
}

// MARK: - Semantic Colors

extension Color {
    // Primary palette
    static let ffPrimary = Color(red: 0.388, green: 0.400, blue: 0.945)   // #6366F1
    static let ffPrimaryLight = Color(red: 0.510, green: 0.518, blue: 0.953)

    // Backgrounds
    static let ffBgDark = Color(red: 0.118, green: 0.118, blue: 0.141)     // #1E1E24
    static let ffSurface = Color(red: 0.165, green: 0.165, blue: 0.196)    // #2A2A32

    // Text
    static let ffTextPrimary = Color(red: 0.941, green: 0.941, blue: 0.961)  // #F0F0F5
    static let ffTextSecondary = Color(red: 0.557, green: 0.557, blue: 0.604) // #8E8E9A

    // Accent
    static let ffSuccess = Color(red: 0.176, green: 0.831, blue: 0.749)    // #2DD4BF

    // Warning banner
    static let ffWarningBg = Color.yellow.opacity(0.08)
}

// MARK: - Gradient Focus Button Style

struct FocusButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLG)
                    .fill(
                        LinearGradient(
                            colors: isActive
                                ? [Color.orange, Color.orange.opacity(0.8)]
                                : [Color.ffPrimary, Color.ffPrimaryLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundColor(.white)
            .shadow(color: Color.ffPrimary.opacity(configuration.isPressed ? 0.1 : 0.3),
                    radius: configuration.isPressed ? 4 : 8,
                    y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Timer Chip Style

struct TimerChipStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .fill(isSelected ? Color.ffPrimary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                    .stroke(
                        isSelected ? Color.ffPrimary : Color.secondary.opacity(0.15),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }
}
