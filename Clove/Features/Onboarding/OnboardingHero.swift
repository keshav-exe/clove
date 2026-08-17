import AppKit
import SwiftUI

/// Full-bleed gradient band at the top of the onboarding sheet.
struct OnboardingHero: View {
    let step: OnboardingStep

    var body: some View {
        ZStack {
            OnboardingStyle.heroGradient

            RadialGradient(
                colors: [.white.opacity(0.35), .clear],
                center: .init(x: 0.22, y: 0.1),
                startRadius: 0,
                endRadius: 260
            )

            emblem
        }
        .frame(height: OnboardingStyle.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var emblem: some View {
        if step == .welcome {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
        } else {
            Image(systemName: step.symbolName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(.white.opacity(0.18), in: .rect(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
    }
}
