import SwiftUI

struct ResourceActionsMenu: View {
    let resource: AgentResource
    let confirmTrash: () -> Void

    var body: some View {
        Menu("More", systemImage: "ellipsis") {
            Button("Open in Default Editor", systemImage: "doc.text", action: open)
            Button("Reveal in Finder", systemImage: "folder", action: reveal)
            Button("Copy Path", systemImage: "doc.on.doc", action: copyPath)

            if let command = removeCommand {
                Divider()
                Button("Copy Remove Command", systemImage: "terminal") {
                    copy(command)
                }
                .help(command)
            }

            if resource.isFileBacked {
                Divider()
                Button("Move to Trash…", systemImage: "trash", role: .destructive, action: confirmTrash)
            }
        }
        .menuIndicator(.hidden)
    }

    /// Shared config files belong to the agent; its own CLI removes entries safely.
    private var removeCommand: String? {
        guard resource.kind == .mcpServers, let name = resource.configKey else { return nil }
        switch resource.agent {
        case .claudeCode:
            let scope = resource.fileURL.lastPathComponent == ".mcp.json" ? "project" : (resource.scope.isGlobal ? "user" : "local")
            return "claude mcp remove \"\(name)\" --scope \(scope)"
        case .codex:
            return "codex mcp remove \"\(name)\""
        case .gemini:
            return "gemini mcp remove \"\(name)\""
        default:
            return nil
        }
    }

    private func open() {
        NSWorkspace.shared.open(resource.fileURL)
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([resource.fileURL])
    }

    private func copyPath() {
        copy(resource.fileURL.path(percentEncoded: false))
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
