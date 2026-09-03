import SwiftUI

struct SkillFileInfo: View {
    let entry: CatalogEntry
    var showsPath: Bool

    private var skill: Skill { entry.primary }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            LabeledContent("Folder", value: skill.directoryName)

            LabeledContent("Modified") {
                Text(skill.modifiedAt, format: .dateTime.day().month().year().hour().minute())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if showsPath {
                LabeledContent("Path") {
                    Text(skill.resolvedPath)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
