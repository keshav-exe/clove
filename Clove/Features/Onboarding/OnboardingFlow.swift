import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHero(step: step)

            VStack(spacing: 0) {
                OnboardingHeader(step: step)
                    .padding(.top, 26)
                    .padding(.bottom, 22)

                stepContent
                    .frame(maxWidth: step.contentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .id(step)
            .transition(stepTransition)
            .padding(.horizontal, OnboardingStyle.horizontalPadding)

            OnboardingFooter(step: step, onBack: goBack, onContinue: goForward)
        }
        .frame(width: OnboardingStyle.width, height: OnboardingStyle.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(Motion.selection(reduceMotion), value: step)
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity
            )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: OnboardingWelcomeStep()
        case .privacy: OnboardingPrivacyStep()
        case .permissions: OnboardingPermissionsStep()
        case .folders: OnboardingFoldersStep()
        case .shortcut: OnboardingShortcutStep()
        }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    private func goForward() {
        if let next = step.next {
            step = next
        } else {
            model.settings.hasCompletedOnboarding = true
            dismiss()
            Task { await model.refresh() }
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppModel.preview)
}
