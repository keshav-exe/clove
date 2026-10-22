import SwiftUI

/// Warns before editing a skill that something else will overwrite.
struct SkillEditorNotice: View {
    @Environment(AppModel.self) private var model
    let fileURL: URL
    let folderName: String

    var body: some View {
        if let message {
            Label(message, systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.spacingL)
                .padding(.vertical, Metrics.spacingS)
                .background(.quaternary.opacity(0.4))
        }
    }

    private var message: String? {
        if fileURL.lastPathComponent == "SKILL.md", let entry = model.manager.lockEntries[folderName] {
            return "Installed from \(entry.source). Updating it replaces your edits; the old copy goes to the Trash."
        }
        let path = fileURL.path(percentEncoded: false)
        let source = model.skills.first { $0.resolvedPath == path }?.source
        switch source {
        case .plugin:
            return "This skill ships with a plugin. The plugin may overwrite your edits when it updates."
        case .cursorBuiltin:
            return "This is a Cursor built-in skill. Cursor may overwrite your edits when it updates."
        default:
            return nil
        }
    }
}
