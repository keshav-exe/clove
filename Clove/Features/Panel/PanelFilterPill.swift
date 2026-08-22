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

                Button("Copy Group", systemImage: "doc.on.doc", action: model.copyActiveTagGroup)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(model.activeTag.map { model.skills(inGroup: $0).isEmpty } ?? true)
                    .help("Copy every skill in this group, separated by spaces")

                Button(model.isGroupPinned(tag) ? "Unpin" : "Pin", systemImage: model.isGroupPinned(tag) ? "pin.fill" : "pin") {
                    model.togglePinGroup(tag)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(model.isGroupPinned(tag) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .help(model.isGroupPinned(tag) ? "Remove from pinned groups" : "Pin to quick access panel")
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 5)
    }
}
