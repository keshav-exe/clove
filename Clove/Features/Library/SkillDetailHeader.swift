import SwiftUI

struct SkillDetailHeader: View {
    let skill: Skill

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.spacingM) {
            IconTile(
                systemImage: skill.source.symbolName,
                tint: skill.source.tint,
                size: Metrics.detailIcon
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var sourceLabel: String {
        if let detail = skill.sourceDetail {
            "\(skill.source.sectionTitle) · \(detail)"
        } else {
            skill.source.sectionTitle
        }
    }
}
