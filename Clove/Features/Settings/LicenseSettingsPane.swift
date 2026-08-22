import AppKit
import SwiftUI

struct LicenseSettingsPane: View {
    @Environment(LicenseService.self) private var license

    var body: some View {
        SettingsForm(centered: true) {
            VStack(alignment: .leading, spacing: 0) {
                if license.isUnlocked, let record = license.record {
                    SettingsFieldRow(label: "Status") {
                        if license.isValidating {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Active")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let email = record.customerEmail {
                        SettingsFieldRow(label: "Email") {
                            Text(email)
                        }
                    }

                    SettingsFieldRow(label: "Device") {
                        Text(record.instanceName)
                    }

                    Button("Verify License") {
                        Task { await license.bootstrap() }
                    }
                    .padding(.top, Metrics.spacingS)
                    .disabled(license.isValidating)

                    Button("Deactivate This Mac", role: .destructive) {
                        Task { await license.deactivate() }
                    }
                    .padding(.top, Metrics.spacingXS)
                    .disabled(license.isValidating)
                } else {
                    SettingsFieldRow(label: "Status") {
                        Text("Not activated")
                            .foregroundStyle(.secondary)
                    }

                    Button("Activate in Library…") {
                        WindowBridge.shared.showLibraryWindow()
                    }
                    .padding(.top, Metrics.spacingS)
                }

                SettingsPaneDivider()

                Button("Open Store") {
                    NSWorkspace.shared.open(LicenseConfiguration.purchaseURL)
                }
            }
        }
    }
}

#Preview {
    LicenseSettingsPane()
        .environment(LicenseService.shared)
}
