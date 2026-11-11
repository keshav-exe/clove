import AppKit
import SwiftUI

/// Shown instead of the library until this Mac has a license: what Clove
/// holds on the left, the key on the right.
struct ActivationView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ActivationShowcase()

            ActivationForm()
                .frame(width: 420)
                .frame(maxHeight: .infinity)
                .background(Palette.background)
        }
        .ignoresSafeArea()
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

/// The paper panel: mockups of the real thing, and what a key unlocks.
private struct ActivationShowcase: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: Metrics.spacingXL) {
            MockStack(height: 230) {
                MockFileCard(fileName: "CLAUDE.md", agent: ("Claude Code", .orange), lines: ["## Conventions", "Use SwiftUI and Swift 6."])
            } middle: {
                MockKeyCard(name: "OPENAI_API_KEY")
            } front: {
                MockSkillCard(reference: "/swiftui-pro", summary: "Reviews SwiftUI for modern APIs and accessibility.", badges: [("Claude Code", .orange), ("Codex", .green)])
            }
            .scaleEffect(1.15)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 10)

            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                ActivationPoint(symbolName: "magnifyingglass", text: "Every skill on your Mac, one shortcut away")
                ActivationPoint(symbolName: "text.document", text: "Every agent's setup, side by side")
                ActivationPoint(symbolName: "leaf", text: "Cleanup that frees context and disk")
            }
            .frame(width: 300, alignment: .leading)
        }
        .padding(Metrics.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surfaceMuted.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 0.5)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) {
                hasAppeared = true
            }
        }
    }
}

private struct ActivationPoint: View {
    let symbolName: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Palette.inkSecondary)
        } icon: {
            Image(systemName: symbolName)
                .foregroundStyle(Palette.accent)
                .frame(width: 20)
        }
        .font(.callout)
    }
}

/// Key in, Clove unlocked. One primary action; buying is the quieter one.
private struct ActivationForm: View {
    @Environment(AppModel.self) private var model
    @State private var key = ""
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        let license = model.license
        let canActivate = !key.trimmingCharacters(in: .whitespaces).isEmpty && !license.isWorking

        VStack(alignment: .leading, spacing: Metrics.spacingL) {
            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .padding(.leading, -6)
                    .accessibilityHidden(true)

                Text("Unlock Clove")
                    .font(.largeTitle.weight(.semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)

                Text("Enter the key from your purchase email.")
                    .foregroundStyle(Palette.inkSecondary)
            }

            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                Text("License key")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.inkSecondary)

                TextField("License key", text: $key, prompt: Text("XXXX-XXXX-XXXX-XXXX"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .focused($isKeyFocused)
                    .disabled(license.isWorking)
                    .onSubmit(activate)
                    .onChange(of: key) {
                        license.failure = nil
                    }
                    .overlay {
                        if license.failure != nil {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(.red.opacity(0.8), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }

                if let failure = license.failure {
                    Label(failure.message, systemImage: "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }

            VStack(spacing: Metrics.spacingS) {
                Button(action: activate) {
                    ZStack {
                        Text("Activate")
                            .opacity(license.isWorking ? 0 : 1)
                        if license.isWorking {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)
                .disabled(!canActivate)

                Link(destination: LicenseConfiguration.checkoutURL) {
                    Text("Buy Clove · $10 \(Image(systemName: "arrow.up.right"))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
            }

            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text("One payment, no subscription. One key per Mac.")
                Link("Clove is open source. Build it yourself for free.", destination: URL(string: "https://github.com/keshav-exe/clove#build-from-source")!)
            }
            .font(.caption)
            .foregroundStyle(Palette.inkTertiary)
            .tint(Palette.inkSecondary)
        }
        .padding(.horizontal, 44)
        .frame(maxHeight: .infinity)
        .animation(.snappy(duration: 0.25), value: license.failure)
        .onAppear {
            isKeyFocused = true
        }
    }

    private func activate() {
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            await model.license.activate(key: key)
        }
    }
}
