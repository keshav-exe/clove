import SwiftUI

struct PanelFilterPill: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            if let tag = model.activeTag {
                Text("Group")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                TagChip(title: tag, isActive: true, onSelect: model.clearTagFilter, onRemove: model.clearTagFilter)

                Spacer(minLength: Metrics.spacingS)

                Button("Copy all", systemImage: "doc.on.doc", action: model.copyActiveTagGroup)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(model.visibleSkills.isEmpty)
                    .help("Copy every skill in this group, separated by spaces")
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 5)
    }
}
