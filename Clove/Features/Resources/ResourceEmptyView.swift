import SwiftUI

/// Teaches what belongs in an empty list and where it would come from.
struct ResourceEmptyView: View {
    let kind: ResourceKind
    let query: String
    let isScanning: Bool

    var body: some View {
        if isScanning {
            ProgressView()
                .controlSize(.small)
        } else if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView {
                Label("No \(kind.title)", systemImage: kind.symbolName)
            } description: {
                Text(kind.explanation + " " + whereToFind)
            }
        }
    }

    private var whereToFind: String {
        switch kind {
        case .instructions: "Add a CLAUDE.md or AGENTS.md to a project or to ~/.claude."
        case .rules: "Cursor reads them from .cursor/rules in each project."
        case .commands: "Claude Code reads them from ~/.claude/commands, Cursor from ~/.cursor/commands."
        case .subagents: "Claude Code reads them from ~/.claude/agents."
        case .mcpServers: "Add one with claude mcp add, or in Cursor's MCP settings."
        case .hooks: "Claude Code reads them from settings.json, Cursor from hooks.json."
        case .permissions: "Claude Code saves them when you approve a command with “always allow.”"
        }
    }
}
