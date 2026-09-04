import AppKit
import SwiftUI

struct PanelSkillRow: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry

    private var skill: Skill { entry.primary }

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

                if model.isSelected(skill) {
                    KeyHint(symbol: "↩")
                }
            }

            SourceBadgeRow(items: entry.sourceBadges)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: handleTap)
        .skillDraggable(skill)
        .help("\(entry.reference) — Return inserts into the prompt you came from")
        .contextMenu {
            SkillActionButtons(skill: skill)
        }
    }

    private func handleTap() {
        model.select(skill, modifiers: NSEvent.modifierFlags)
    }
}
