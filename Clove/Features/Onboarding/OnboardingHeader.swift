import SwiftUI

struct OnboardingHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 7) {
            Text(step.title)
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: OnboardingStyle.contentWidth)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
