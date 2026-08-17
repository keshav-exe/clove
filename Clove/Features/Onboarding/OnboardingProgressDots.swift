import SwiftUI

struct OnboardingProgressDots: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 5) {
            ForEach(OnboardingStep.allCases) { item in
                Capsule(style: .continuous)
                    .fill(item == step ? Color.secondary.opacity(0.75) : Color.secondary.opacity(0.22))
                    .frame(width: item == step ? 16 : 6, height: 6)
            }
        }
        .animation(Motion.easeOutCubic, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }
}
