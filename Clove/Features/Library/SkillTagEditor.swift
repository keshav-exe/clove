import SwiftUI

struct SkillTagEditor: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    @State private var draft = ""

    private var groups: [String] {
        model.tags(for: skill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            if groups.isEmpty {
                Text("No groups yet. Groups are stored locally and make search faster.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            HStack(spacing: Metrics.spacingS) {
                TextField("Add to group", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commit)

                Menu {
                    ForEach(model.allGroups, id: \.self) { group in
                        if !groups.contains(where: { $0.localizedStandardCompare(group) == .orderedSame }) {
                            Button(group) {
                                model.addSkillToGroup(skill, group: group)
                            }
                        }
                    }
                    if model.allGroups.isEmpty {
                        Text("No groups yet")
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .menuStyle(.borderlessButton)
                .help("Add to an existing group")

                Button("Add", action: commit)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commit() {
        model.addTag(draft, to: skill)
        draft = ""
    }
}
