import SwiftUI

struct OnboardingFooter: View {
    let step: OnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingProgressDots(step: step)

            HStack {
                Button("Back", action: onBack)
                    .buttonStyle(.link)
                    .foregroundStyle(.secondary)
                    .opacity(step.previous == nil ? 0 : 1)
                    .disabled(step.previous == nil)

                Spacer()

                Button(step.continueTitle, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, OnboardingStyle.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 22)
    }
}
