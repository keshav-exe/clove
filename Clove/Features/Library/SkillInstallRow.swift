import SwiftUI

struct SkillInstallRow: View {
    @Environment(AppModel.self) private var model
    let skill: Skill

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.source.sectionTitle)
                    .font(.body)

                Text(skill.resolvedPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Reveal in Finder", systemImage: "folder", action: reveal)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Reveal in Finder")

            Button("Open in Default Editor", systemImage: "arrow.up.forward.app", action: open)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Open in Default Editor")
        }
        .padding(.vertical, 5)
    }

    private func reveal() {
        model.reveal(skill)
    }

    private func open() {
        model.open(skill)
    }
}
