import SwiftUI

struct SkillDetailHeader: View {
    let entry: CatalogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text(entry.displayName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            SourceBadgeRow(items: entry.sourceBadges)

            if entry.isLinked {
                Text("Linked across \(entry.sourceBadges.count) locations with the same reference.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
