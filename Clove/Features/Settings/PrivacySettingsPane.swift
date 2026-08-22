import AppKit
import SwiftUI

struct PrivacySettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingReset = false

    var body: some View {
        SettingsForm {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                SettingsSection {
                    SettingsFieldRow(label: "Accessibility") {
                        if AccessibilityAccess.isGranted {
                            Text("Enabled")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Open Settings…") {
                                AccessibilityAccess.openSettings()
                            }
                        }
                    }
                }

                SettingsPaneDivider()

                SettingsSection {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(PrivacyPromise.all) { promise in
                            SettingsPromiseRow(promise: promise)
                        }
                    }
                }

                SettingsPaneDivider()

                SettingsSection {
                    SettingsFieldRow(label: "Group storage") {
                        Button("Reveal in Finder", action: revealTagFile)
                    }

                    SettingsFieldRow(label: "Delete groups") {
                        Button("Delete…", role: .destructive) {
                            isConfirmingReset = true
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete all local groups?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete Groups", role: .destructive, action: model.resetLocalTags)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your SKILL.md files are not changed. Only groups you created in Clove are removed.")
        }
    }

    private func revealTagFile() {
        NSWorkspace.shared.activateFileViewerSelecting([model.tagsFileURL])
    }
}
