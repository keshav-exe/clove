import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        FeatureSheet(
            useAppIcon: step == .welcome,
            symbolName: step == .welcome ? nil : step.symbolName,
            title: step.title,
            subtitle: step.subtitle,
            pageIndex: step.rawValue,
            pageCount: OnboardingStep.allCases.count,
            continueTitle: step.continueTitle,
            showsBack: step.previous != nil,
            onBack: goBack,
            onContinue: goForward
        ) {
            stepContent
                .id(step)
                .transition(stepTransition)
        }
        .animation(Motion.selection(reduceMotion), value: step)
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 6)),
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
        case .features: OnboardingFeaturesStep()
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
            model.settings.lastSeenWhatsNewVersion = AppVersion.short
            dismiss()
            Task { await model.refresh() }
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppModel.preview)
}
