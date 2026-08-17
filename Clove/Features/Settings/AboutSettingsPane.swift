import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SettingsPaneLayout {
            VStack(spacing: Metrics.spacingS) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                Text("Clove")
                    .font(.title2.weight(.semibold))

                Text("Version \(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metrics.spacingM)

            SettingsGroup(title: "Library") {
                SettingsActionRow(
                    systemImage: "square.stack.3d.up",
                    tint: .accentColor,
                    title: "Skills indexed",
                    detail: "Across every folder Clove is allowed to read."
                ) {
                    Text("\(model.skills.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.leading, 46)

                SettingsActionRow(
                    systemImage: "tag",
                    tint: .teal,
                    title: "Tags in use",
                    detail: "Tags from skill frontmatter plus your own."
                ) {
                    Text("\(model.allUserFacingTags.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
