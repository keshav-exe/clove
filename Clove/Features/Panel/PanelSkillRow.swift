import AppKit
import SwiftUI

struct PanelSkillRow: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry

    private var skill: Skill { entry.primary }

    private var isSelected: Bool {
        model.isSelected(skill)
    }

    private var tags: [String] {
        model.tags(for: entry)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingS) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.displayName)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)

                    if !entry.summary.isEmpty {
                        Text(entry.summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Metrics.spacingXS)

                if isSelected {
                    KeyHint(symbol: "↩")
                }
            }

            SourceBadgeRow(items: entry.sourceBadges)

            if isSelected, !tags.isEmpty {
                WrappingTagRow(tags: tags) { tag in
                    TagChip(
                        title: tag,
                        isActive: model.activeTag == tag,
                        onSelect: { model.toggleTagFilter(tag) },
                        onRemove: model.isUserTag(tag, for: entry)
                            ? { model.removeTag(tag, from: skill) }
                            : nil,
                        onCopy: { model.copyGroup(tag) }
                    )
                }
            }
        }
        .padding(.horizontal, Metrics.rowPaddingHorizontal)
        .padding(.vertical, Metrics.rowPaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.16) : .clear,
            in: .rect(cornerRadius: Metrics.rowRadius)
        )
        .contentShape(.rect(cornerRadius: Metrics.rowRadius))
        .onTapGesture(perform: handleTap)
        .skillDraggable(skill)
        .help("\(entry.reference) — Return inserts into the prompt you came from")
        .contextMenu {
            SkillActionButtons(skill: skill)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleTap() {
        model.select(skill, modifiers: NSEvent.modifierFlags)
    }
}
