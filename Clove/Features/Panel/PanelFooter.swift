import SwiftUI

struct PanelFooter: View {
    @Environment(AppModel.self) private var model

    private var groups: [String] {
        if let activeTag = model.activeTag {
            return [activeTag]
        }
        guard let skill = model.selectedSkill else { return [] }
        return model.tags(for: skill)
    }

    var body: some View {
        VStack(spacing: 0) {
            groupActionsRow
                .opacity(groups.isEmpty ? 0 : 1)
                .allowsHitTesting(!groups.isEmpty)

            Divider()
                .opacity(0.6)

            PanelShortcutHints()
        }
    }

    private var groupActionsRow: some View {
        HStack(spacing: Metrics.spacingS) {
            Image(systemName: "folder")
                .font(.system(size: 10))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            if groups.count == 1, let group = groups.first {
                Text(group)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("\(groups.count) groups")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Metrics.spacingS)

            if groups.count == 1, let group = groups.first {
                pinButton(for: group)
                copyButton(for: group)
            } else {
                Menu {
                    ForEach(groups, id: \.self) { group in
                        Section(group) {
                            Button("Copy Group", systemImage: "doc.on.doc") {
                                model.copyGroup(group)
                            }
                            Button(model.isGroupPinned(group) ? "Unpin" : "Pin", systemImage: "pin") {
                                model.togglePinGroup(group)
                            }
                            Button("Filter", systemImage: "line.3.horizontal.decrease") {
                                model.toggleTagFilter(group)
                            }
                        }
                    }
                } label: {
                    Label("Copy Group", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .foregroundStyle(.secondary)
                .fixedSize()
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .frame(height: 30)
    }

    private func pinButton(for group: String) -> some View {
        Button(model.isGroupPinned(group) ? "Unpin" : "Pin", systemImage: model.isGroupPinned(group) ? "pin.fill" : "pin") {
            model.togglePinGroup(group)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(model.isGroupPinned(group) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        .help(model.isGroupPinned(group) ? "Remove from pinned groups" : "Pin to quick access panel")
    }

    private func copyButton(for group: String) -> some View {
        Button("Copy Group", systemImage: "doc.on.doc") {
            model.copyGroup(group)
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 11))
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(model.skills(inGroup: group).isEmpty)
        .help("Copy every skill reference in this group")
    }
}
