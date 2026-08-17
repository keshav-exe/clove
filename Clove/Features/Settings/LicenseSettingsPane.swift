import AppKit
import SwiftUI

struct LicenseSettingsPane: View {
    @Environment(LicenseService.self) private var license

    var body: some View {
        SettingsPaneLayout {
            SettingsGroup(title: "License") {
                if license.isUnlocked, let record = license.record {
                    SettingsActionRow(
                        systemImage: "checkmark.seal.fill",
                        tint: .green,
                        title: "Activated",
                        detail: record.customerEmail ?? "Licensed on this Mac."
                    ) {
                        if license.isValidating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Active")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider().padding(.leading, 46)

                    SettingsActionRow(
                        systemImage: "desktopcomputer",
                        tint: .blue,
                        title: record.instanceName,
                        detail: "Uses one of your \(LicenseConfiguration.activationLimit) device activations."
                    ) {
                        EmptyView()
                    }

                    Divider().padding(.leading, 46)

                    SettingsActionRow(
                        systemImage: "arrow.clockwise",
                        tint: .orange,
                        title: "Check license",
                        detail: "Verify your purchase with Lemon Squeezy."
                    ) {
                        Button("Verify") {
                            Task { await license.bootstrap() }
                        }
                        .disabled(license.isValidating)
                    }

                    Divider().padding(.leading, 46)

                    SettingsActionRow(
                        systemImage: "xmark.circle",
                        tint: .red,
                        title: "Deactivate this Mac",
                        detail: "Free up an activation slot when you move Clove to another computer."
                    ) {
                        Button("Deactivate") {
                            Task { await license.deactivate() }
                        }
                        .disabled(license.isValidating)
                    }
                } else {
                    SettingsActionRow(
                        systemImage: "key.fill",
                        tint: .orange,
                        title: "Not activated",
                        detail: "Enter your license key in the main window."
                    ) {
                        Button("Activate…") {
                            WindowBridge.shared.showLibraryWindow()
                        }
                    }
                }
            }

            SettingsGroup(title: "Purchase") {
                SettingsActionRow(
                    systemImage: "cart",
                    tint: .accentColor,
                    title: "Buy or manage license",
                    detail: "One-time purchase. Intro $19.99, regular $39.00."
                ) {
                    Button("Open Store") {
                        NSWorkspace.shared.open(LicenseConfiguration.purchaseURL)
                    }
                }
            }
        }
    }
}

#Preview {
    LicenseSettingsPane()
        .environment(LicenseService.shared)
        .frame(width: 520, height: 420)
}
