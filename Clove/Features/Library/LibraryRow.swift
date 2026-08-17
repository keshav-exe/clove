import SwiftUI

struct LibraryRow: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingS) {
            IconTile(systemImage: SkillSource.listIcon, tint: skill.source.tint, size: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(skill.summary.isEmpty ? "No description" : skill.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
        .skillDraggable(skill)
        .contextMenu {
            SkillActionButtons(skill: skill)
        }
    }
}
