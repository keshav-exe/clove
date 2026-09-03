import SwiftUI

struct SkillDetailHeader: View {
    let entry: CatalogEntry

    private var skill: Skill { entry.primary }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displayName)
                    .font(.title2)
                    .textSelection(.enabled)

                SkillReferenceChip(skill: skill)
            }

            SourceBadgeRow(items: entry.sourceBadges)

            if entry.isLinked {
                Text("Same reference in \(entry.sourceBadges.count) places.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(entry.summary.isEmpty ? "This skill has no description." : entry.summary)
                .font(.body)
                .foregroundStyle(entry.summary.isEmpty ? .tertiary : .secondary)
                .textSelection(.enabled)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
