import AppKit
import SwiftUI

struct PrivacySettingsPane: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingReset = false
    @State private var accessibility = AccessibilityAccess.isGranted

    var body: some View {
        SettingsPage {
            Section {
                SettingsRow(title: "Accessibility", subtitle: "Lets Clove type a skill into the app you were in", symbol: "accessibility", tint: Palette.Vivid.blue) {
                    if accessibility {
                        StatusBadge(text: "Allowed")
                    } else {
                        Button("Allow…") { AccessibilityAccess.openSettings() }
                    }
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Everything else Clove does works without it: copying a skill always does.")
                    .settingsFooter()
            }

            Section("Clove's Promise") {
                ForEach(PrivacyPromise.all) { promise in
                    SettingsLabel(title: promise.title, subtitle: promise.detail, symbol: promise.symbolName, tint: Palette.Vivid.green)
                        .padding(.vertical, 2)
                }
            }

            Section {
                SettingsRow(title: "Your groups", subtitle: "One JSON file in Clove's Application Support folder", symbol: "doc.fill", tint: Color(white: 0.45)) {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.tagsFileURL]) }
                }
                SettingsRow(title: "Delete all groups", subtitle: "Your SKILL.md files stay as they are", symbol: "trash.fill", tint: Palette.Vivid.red) {
                    Button("Delete…", role: .destructive) { isConfirmingReset = true }
                }
            } header: {
                Text("Your Data")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibility = AccessibilityAccess.isGranted
        }
        .confirmationDialog("Delete all local groups?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Delete Groups", role: .destructive, action: model.resetLocalTags)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your SKILL.md files are not changed. Only groups you created in Clove are removed.")
        }
    }
}
