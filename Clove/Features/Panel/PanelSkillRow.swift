import AppKit
import SwiftUI

struct PanelSkillRow: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    private var isSelected: Bool {
        model.isSelected(skill)
    }

    private var tags: [String] {
        model.tags(for: skill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Metrics.spacingS) {
                Image(systemName: SkillSource.listIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accentColor : skill.source.tint)
                    .frame(width: 14)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.displayName)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)

                    if !skill.summary.isEmpty {
                        Text(skill.summary)
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

            if isSelected, !tags.isEmpty {
                WrappingTagRow(tags: tags) { tag in
                    TagChip(
                        title: tag,
                        isActive: model.activeTag == tag,
                        onSelect: { model.toggleTagFilter(tag) },
                        onRemove: model.isUserTag(tag, for: skill)
                            ? { model.removeTag(tag, from: skill) }
                            : nil
                    )
                }
                .padding(.leading, 22)
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
        .help("\(skill.reference) — Return copies, drag to drop into a prompt")
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
