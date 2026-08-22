import SwiftUI

struct PanelShortcutHints: View {
    @Environment(AppModel.self) private var model

    private var hasSelection: Bool {
        !model.selectedSkills.isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            hint(keys: ["↑↓"], label: "move")
            hint(keys: ["↩"], label: "copy")
            hint(keys: ["⌘↩"], label: "insert")

            if !model.pinnedGroups.isEmpty {
                hint(keys: ["⇥"], label: "groups")
            }

            if model.selectedSkill.map({ !model.tags(for: $0).isEmpty }) == true || model.activeTag != nil {
                hint(keys: ["⌘⇧C"], label: "copy group")
            }

            Spacer(minLength: 0)

            if model.selectedSkills.count > 1 {
                Text("\(model.selectedSkills.count) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .opacity(hasSelection ? 1 : 0.55)
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["Arrow keys move", "Return copies", "Command Return inserts"]
        if !model.pinnedGroups.isEmpty {
            parts.append("Tab cycles pinned groups")
        }
        if model.selectedSkill.map({ !model.tags(for: $0).isEmpty }) == true || model.activeTag != nil {
            parts.append("Command Shift C copies the group")
        }
        return parts.joined(separator: ", ")
    }

    private func hint(keys: [String], label: String) -> some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 4, style: .continuous))
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHidden(true)
    }
}
