import SwiftUI

struct SkillDetailHeader: View {
    let skill: Skill

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.spacingM) {
            SourceColorBlock(tint: skill.source.tint, size: 14)
                .frame(width: Metrics.detailIcon, height: Metrics.detailIcon)
                .background(skill.source.tint.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))

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
