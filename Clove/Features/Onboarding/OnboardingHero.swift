import SwiftUI

/// A paper band at the top of the onboarding sheet, showing what the step is about.
struct OnboardingHero: View {
    let step: OnboardingStep

    var body: some View {
        ZStack {
            Palette.surfaceMuted

            OnboardingArt(step: step)
                .padding(.top, 8)
                .id(step)
                .transition(.opacity)
        }
        .frame(height: OnboardingStyle.heroHeight)
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }
}
