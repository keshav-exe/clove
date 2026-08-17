import SwiftUI

enum OnboardingStyle {
    static let width: Double = 680
    static let height: Double = 624

    static let heroHeight: Double = 148
    static let contentWidth: Double = 460
    static let horizontalPadding: Double = 44

    static let brand = Color(red: 0.0, green: 0.87, blue: 0.75)
    static let brandDeep = Color(red: 0.13, green: 0.45, blue: 0.95)

    static let heroGradient = LinearGradient(
        colors: [brand, Color(red: 0.16, green: 0.72, blue: 0.90), brandDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Tinted glyph tile used by every onboarding row. One tint keeps the flow cohesive.
struct OnboardingTile: View {
    let systemImage: String
    var tint: Color = OnboardingStyle.brandDeep

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Unboxed feature row: glyph, title, one line of supporting copy.
struct OnboardingRow<Trailing: View>: View {
    let systemImage: String
    var tint: Color = OnboardingStyle.brandDeep
    let title: String
    let detail: String
    var badge: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            OnboardingTile(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout.weight(.semibold))

                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.fill.tertiary, in: Capsule())
                    }
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)
            }

            Spacer(minLength: 8)

            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

extension OnboardingRow where Trailing == EmptyView {
    init(systemImage: String, tint: Color = OnboardingStyle.brandDeep, title: String, detail: String, badge: String? = nil) {
        self.init(systemImage: systemImage, tint: tint, title: title, detail: detail, badge: badge) {
            EmptyView()
        }
    }
}
