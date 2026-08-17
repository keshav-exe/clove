import SwiftUI

struct PanelShortcutHints: View {
    @Environment(AppModel.self) private var model

    private var hasSelection: Bool {
        !model.selectedSkills.isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            hint(keys: ["↑", "↓"], label: "move")
            hint(keys: ["↩"], label: "copy")
            hint(keys: ["⌘↩"], label: "insert")
            hint(keys: ["⇥"], label: "tag")

            Spacer(minLength: 0)

            if model.selectedSkills.count > 1 {
                Text("\(model.selectedSkills.count) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .opacity(hasSelection ? 1 : 0.55)
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Arrow keys move, Return copies, Command Return inserts, Tab jumps to the tag field")
    }

    private func hint(keys: [String], label: String) -> some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 11)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 4, style: .continuous))
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .accessibilityHidden(true)
    }
}
