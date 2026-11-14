import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @State private var whatsNewRelease: WhatsNewRelease?
    @State private var isConfirmingDeactivate = false

    var body: some View {
        SettingsForm(centered: true) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsFieldRow(label: "Version") {
                    Text(AppVersion.display)
                }

                if LicenseConfiguration.isRequired, let license = model.license.license {
                    SettingsFieldRow(label: "License") {
                        HStack(spacing: Metrics.spacingS) {
                            Text("Active on this Mac · \(license.maskedKey)")
                                .foregroundStyle(.secondary)
                            if model.license.isWorking {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Deactivate…") {
                                    isConfirmingDeactivate = true
                                }
                            }
                        }
                    }
                }

                SettingsFieldRow(label: "Updates") {
                    VStack(alignment: .leading, spacing: Metrics.spacingS) {
                        Toggle("Install updates automatically", isOn: Binding(
                            get: { updates.isAutomatic },
                            set: { updates.isAutomatic = $0 }
                        ))
                        Button("Check for Updates…") { updates.checkNow() }
                            .disabled(!updates.canCheck)
                    }
                }

                SettingsFieldRow(label: "What's New") {
                    Button("Show Release Notes…") {
                        whatsNewRelease = WhatsNewCatalog.latest
                    }
                }

                SettingsPaneDivider()

                SettingsFieldRow(label: "Skills indexed") {
                    Text("\(model.catalog.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                SettingsFieldRow(label: "Groups in use") {
                    Text("\(model.allGroups.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog("Deactivate Clove on this Mac?", isPresented: $isConfirmingDeactivate, titleVisibility: .visible) {
            Button("Deactivate", role: .destructive) {
                Task { await model.license.deactivate() }
            }
        } message: {
            Text("Your key becomes free to use on another Mac, and Clove locks here until you enter it again.")
        }
        .alert(
            model.license.failure?.message ?? "",
            isPresented: Binding(
                get: { model.license.failure != nil && model.license.isUnlocked },
                set: { if !$0 { model.license.failure = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $whatsNewRelease) { release in
            WhatsNewSheet(release: release) {
                model.settings.lastSeenWhatsNewVersion = release.version
            }
        }
    }
}
