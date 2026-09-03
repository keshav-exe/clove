import SwiftUI

struct SkillReferenceChip: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            Text(skill.reference)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .accessibilityLabel("Reference \(skill.reference)")

            Button(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc", action: copy)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Copy \(skill.reference)")
        }
        .sensoryFeedback(.success, trigger: didCopy)
    }

    private func copy() {
        model.copyReference(skill)
        didCopy = true
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .milliseconds(1_500))
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}
