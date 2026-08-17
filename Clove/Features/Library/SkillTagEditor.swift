import SwiftUI

struct SkillTagEditor: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    @State private var draft = ""

    private var tags: [String] {
        model.tags(for: skill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            if tags.isEmpty {
                Text("No tags yet. Tags are stored locally and make search faster.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                WrappingTagRow(tags: tags) { tag in
                    TagChip(
                        title: tag,
                        isActive: model.libraryFilter == .tag(tag),
                        onSelect: { model.libraryFilter = .tag(tag) },
                        onRemove: model.isUserTag(tag, for: skill)
                            ? { model.removeTag(tag, from: skill) }
                            : nil
                    )
                }
            }

            HStack(spacing: Metrics.spacingS) {
                TextField("Add a tag", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commit)

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
