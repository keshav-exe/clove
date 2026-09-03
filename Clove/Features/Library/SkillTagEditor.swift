import SwiftUI

struct SkillTagEditor: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    private var groups: [String] {
        model.tags(for: skill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            if groups.isEmpty {
                Text("Not in a group yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                WrappingTagRow(tags: groups) { group in
                    TagChip(
                        title: group,
                        isActive: model.libraryFilter == .tag(group),
                        onSelect: { model.libraryFilter = .tag(group) },
                        onRemove: model.isUserTag(group, for: skill)
                            ? { model.removeTag(group, from: skill) }
                            : nil
                    )
                }
            }

            GroupPickerField(skill: skill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
