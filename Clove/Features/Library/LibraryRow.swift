import SwiftUI

struct LibraryRow: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            HStack(spacing: Metrics.spacingXS) {
                Text(entry.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if model.manager.hasUpdate(entry.primary.directoryName) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.tint)
                        .imageScale(.small)
                        .accessibilityLabel("Update available")
                        .help("A newer version is on GitHub")
                }
            }

            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No description")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            SourceBadgeRow(items: entry.sourceBadges)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .skillDraggable(entry.primary)
        .contextMenu {
            SkillActionButtons(skill: entry.primary)
        }
    }
}
