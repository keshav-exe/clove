import SwiftUI

struct LibraryRow: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(skill.summary.isEmpty ? "No description" : skill.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            SourceColorBlock(tint: skill.source.tint, size: 10)
                .frame(width: 20, height: 20)
        }
        .labelStyle(.titleAndIcon)
        .padding(.vertical, 3)
        .skillDraggable(skill)
        .contextMenu {
            SkillActionButtons(skill: skill)
        }
    }
}
