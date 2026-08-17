import AppKit
import SwiftUI

struct PrivacySettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingReset = false

    var body: some View {
        SettingsPaneLayout {
            SettingsGroup(
                title: "Permissions",
                footnote: "Clove never uploads skill data. These are local macOS permissions only."
            ) {
                SettingsActionRow(
                    systemImage: "accessibility",
                    tint: .orange,
                    title: "Accessibility",
                    detail: "Needed for Return and drag-to-insert into Cursor, Claude, VS Code, Terminal, and other apps."
                ) {
                    if AccessibilityAccess.isGranted {
                        Label("Enabled", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Button("Open Settings…") {
                            AccessibilityAccess.openSettings()
                        }
                    }
                }
            }

            SettingsGroup(
                title: "How Clove Handles Your Data",
                footnote: "No account and no analytics. License verification is the only network traffic."
            ) {
                ForEach(Array(PrivacyPromise.all.enumerated()), id: \.element.id) { index, promise in
                    if index > 0 {
                        Divider().padding(.leading, 46)
                    }
                    SettingsActionRow(
                        systemImage: promise.symbolName,
                        tint: .green,
                        title: promise.title,
                        detail: promise.detail
                    ) {
                        EmptyView()
                    }
                }
            }

            SettingsGroup(title: "Local Data") {
                SettingsActionRow(
                    systemImage: "externaldrive",
                    tint: .gray,
                    title: "Tag storage",
                    detail: shortTagPath
                ) {
                    Button("Reveal", action: revealTagFile)
                }

                Divider().padding(.leading, 46)

                SettingsActionRow(
                    systemImage: "trash",
                    tint: .red,
                    title: "Delete tags",
                    detail: "Removes every tag you added. Skill files are untouched."
                ) {
                    Button("Delete…", role: .destructive) {
                        isConfirmingReset = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete all local tags?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete Tags", role: .destructive, action: model.resetLocalTags)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your SKILL.md files are not changed. Only tags you created in Clove are removed.")
        }
    }

    private var shortTagPath: String {
        model.tagsFileURL
            .path(percentEncoded: false)
            .replacingOccurrences(of: URL.homeDirectory.path(percentEncoded: false), with: "~/")
    }

    private func revealTagFile() {
        NSWorkspace.shared.activateFileViewerSelecting([model.tagsFileURL])
    }
}
