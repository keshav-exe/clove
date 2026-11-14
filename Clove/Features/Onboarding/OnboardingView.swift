import SwiftUI

/// The first-run guide, and the license screen when this Mac has none: words
/// and choices on the left, a small scene on the right showing what the step
/// is about. It fills the main window until setup is done.
enum OnboardingStep: Int, CaseIterable {
    case welcome, license, permissions, shortcut, ready

    /// A first run walks every step. A Mac that finished setup but has no
    /// license (a deactivated key, say) sees the license step alone.
    @MainActor
    static func steps(onboarded: Bool) -> [OnboardingStep] {
        if onboarded { return [.license] }
        return allCases.filter { $0 != .license || LicenseConfiguration.isRequired }
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    /// Kept across launches: macOS asks to reopen Clove after Full Disk Access,
    /// and the guide should pick up where it was.
    @AppStorage("onboardingStep") private var savedStep = OnboardingStep.welcome.rawValue

    private var steps: [OnboardingStep] {
        OnboardingStep.steps(onboarded: model.settings.hasCompletedOnboarding)
    }

    private var step: OnboardingStep {
        let saved = OnboardingStep(rawValue: savedStep) ?? .welcome
        return steps.contains(saved) ? saved : steps[0]
    }

    private var index: Int { steps.firstIndex(of: step) ?? 0 }

    private var canAdvance: Bool {
        step != .license || model.license.isUnlocked
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if steps.count > 1 {
                    StepDots(count: steps.count, current: index)
                        .padding(.bottom, 28)
                }
                Group {
                    switch step {
                    case .welcome: WelcomeStep()
                    case .license: LicenseStep(onActivated: advance)
                    case .permissions: PermissionsStep()
                    case .shortcut: ShortcutStep()
                    case .ready: ReadyStep()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .arrives()
                .id(step)

                if steps.count > 1 { footer }
            }
            .padding(.horizontal, 44)
            .padding(.top, 58)
            .padding(.bottom, 32)
            .frame(width: 460)
            .frame(maxHeight: .infinity)
            .background(Palette.background)

            OnboardingStage(step: step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if index > 0 {
                Button(action: back) {
                    Label("Back", systemImage: "chevron.left")
                        .padding(.vertical, 8)
                        .padding(.trailing, 8)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .foregroundStyle(Palette.inkSecondary)
            }

            Spacer()

            Button(action: advance) {
                HStack(spacing: 8) {
                    Text(nextTitle)
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.7)
                }
                .padding(.horizontal, 6)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(step == .license ? nil : .defaultAction)
            .disabled(!canAdvance)
        }
    }

    private var nextTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .ready: "Start Clove"
        default: "Next"
        }
    }

    private func back() {
        guard index > 0 else { return }
        savedStep = steps[index - 1].rawValue
    }

    private func advance() {
        guard canAdvance else { return }
        if index + 1 < steps.count {
            savedStep = steps[index + 1].rawValue
        } else {
            finish()
        }
    }

    private func finish() {
        savedStep = OnboardingStep.welcome.rawValue
        guard !model.settings.hasCompletedOnboarding else { return }
        model.settings.lastSeenWhatsNewVersion = AppVersion.short
        model.settings.hasCompletedOnboarding = true
    }
}

// MARK: - Pieces

struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.ink : Palette.ink.opacity(0.18))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(.snappy(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

/// A page fades and rises in as it arrives; the one it replaces goes at once,
/// so no half-gone page is ever left under the pointer.
private struct Arrival: ViewModifier {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .onAppear { withAnimation(.smooth(duration: 0.32)) { shown = true } }
    }
}

extension View {
    func arrives() -> some View { modifier(Arrival()) }
}

struct StepHeader: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 28)
    }
}

/// One setting as a raised row: a symbol, what it is, and its control.
struct SettingCard<Control: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control
        }
        .padding(14)
        .onboardingCard()
        .accessibilityElement(children: .contain)
    }
}

struct StatusPill: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.mint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.mint.opacity(0.12), in: .capsule)
    }
}

struct NumberedRow: View {
    let number: Int
    let text: String

    init(_ number: Int, _ text: String) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.accent)
                .frame(width: 22, height: 22)
                .background(Palette.accent.opacity(0.12), in: .circle)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            Text(text)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// The guide's one surface: a raised panel with a hairline edge.
    func onboardingCard() -> some View {
        background(Palette.surface, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.hairline)
            }
    }
}

#Preview {
    OnboardingView()
        .environment(AppModel.preview)
        .frame(width: 960, height: 600)
}
