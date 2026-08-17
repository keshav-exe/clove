import AppKit
import SwiftUI

struct LicenseActivationView: View {
    @Environment(LicenseService.self) private var license
    @State private var licenseKey = ""
    @FocusState private var keyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Metrics.spacingXL)

            VStack(spacing: Metrics.spacingL) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                VStack(spacing: Metrics.spacingS) {
                    Text("Activate Clove")
                        .font(.title.weight(.semibold))

                    Text("Enter the license key from your purchase email. One purchase covers up to \(LicenseConfiguration.activationLimit) Macs.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    TextField("License key", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .focused($keyFocused)
                        .onSubmit(activate)

                    if let error = license.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if case .expiredOffline = license.status {
                        Text("Connect to the internet to verify your license.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 360)

                HStack(spacing: Metrics.spacingM) {
                    Button("Buy Clove") {
                        NSWorkspace.shared.open(LicenseConfiguration.purchaseURL)
                    }

                    Button(license.isValidating ? "Activating…" : "Activate") {
                        activate()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || license.isValidating)
                }

                pricingNote
            }
            .padding(.horizontal, Metrics.spacingXL)

            Spacer(minLength: Metrics.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            keyFocused = true
        }
    }

    private var pricingNote: some View {
        VStack(spacing: Metrics.spacingXS) {
            Text("Introductory price $19.99")
                .font(.caption.weight(.medium))

            Text("Regular price $39.00 · One-time purchase, no subscription")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, Metrics.spacingS)
    }

    private func activate() {
        Task {
            await license.activate(licenseKey: licenseKey)
        }
    }
}

#Preview {
    LicenseActivationView()
        .environment(LicenseService.shared)
        .frame(width: 520, height: 480)
}
