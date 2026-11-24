import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    @Environment(AppModel.self) private var model
    @Environment(UpdateService.self) private var updates
    @State private var whatsNewRelease: WhatsNewRelease?
    @State private var isConfirmingDeactivate = false

    var body: some View {
        SettingsPage {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clove")
                            .font(.title2.weight(.semibold))
                        Text("Version \(AppVersion.display)")
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Your agents' skills, and your Mac, in the notch.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Check for Updates") { updates.checkNow() }
                        .disabled(!updates.canCheck)
                }
                .padding(.vertical, 6)
            }

            Section("Updates") {
                SettingsToggle(
                    title: "Install updates automatically",
                    subtitle: "Downloads in the background and installs when you quit. Every update is signed.",
                    symbol: "arrow.down.circle.fill", tint: Palette.Vivid.blue,
                    isOn: Binding { updates.isAutomatic } set: { updates.isAutomatic = $0 }
                )
                SettingsRow(title: "What's new", subtitle: "What changed in this version", symbol: "sparkles", tint: Palette.Vivid.violet) {
                    Button("Show") { whatsNewRelease = WhatsNewCatalog.latest }
                }
            }

            if LicenseConfiguration.isRequired, let license = model.license.license {
                Section("License") {
                    SettingsRow(title: "Active on this Mac", subtitle: license.maskedKey, symbol: "key.fill", tint: Palette.Vivid.yellow) {
                        if model.license.isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Deactivate…") { isConfirmingDeactivate = true }
                        }
                    }
                }
            }

            Section("On This Mac") {
                LabeledContent("Skills indexed") {
                    Text(model.catalog.count.formatted()).monospacedDigit()
                }
                LabeledContent("Groups") {
                    Text(model.allGroups.count.formatted()).monospacedDigit()
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
