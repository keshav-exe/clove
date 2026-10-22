import SwiftUI

/// Sets the same MCP server up in other agents. Cursor's mcp.json is edited
/// directly; Claude Code and Codex own their config files, so Clove hands you
/// their own add command instead of writing to them.
struct MCPShareSection: View {
    @Environment(AppModel.self) private var model
    let resource: AgentResource

    @State private var copied: AgentApp?

    private var otherAgents: [AgentApp] {
        [.cursor, .claudeCode, .codex].filter { $0 != resource.agent }
    }

    var body: some View {
        SkillDetailSection(title: "Use In") {
            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                ForEach(otherAgents) { agent in
                    HStack(spacing: Metrics.spacingM) {
                        Text(agent.title)
                        Spacer(minLength: Metrics.spacingM)
                        if isConfigured(in: agent) {
                            Text("Already set up")
                                .foregroundStyle(.secondary)
                        } else {
                            Button(actionTitle(for: agent)) { share(with: agent) }
                                .controlSize(.small)
                                .help(help(for: agent))
                        }
                    }
                }
                Text("Copied commands include this server's keys. Paste them into a terminal, not a chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)
        }
        .task(id: copied) {
            guard copied != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = nil
        }
    }

    private func isConfigured(in agent: AgentApp) -> Bool {
        model.resources(of: .mcpServers).contains { $0.agent == agent && $0.name == resource.name && $0.scope.isGlobal }
    }

    private func actionTitle(for agent: AgentApp) -> String {
        if copied == agent { return "Copied" }
        return agent == .cursor ? "Add" : "Copy Command"
    }

    private func help(for agent: AgentApp) -> String {
        switch agent {
        case .cursor: "Add to ~/.cursor/mcp.json"
        case .claudeCode: "Copy a claude mcp add-json command"
        default: "Copy a block for ~/.codex/config.toml"
        }
    }

    private func share(with agent: AgentApp) {
        guard let config = MCPServerConfig.load(from: resource) else {
            model.manager.failure = ManagerFailure(title: "Couldn't read \(resource.name)", message: "Its entry in \(resource.fileURL.lastPathComponent) changed or can't be parsed.")
            return
        }
        switch agent {
        case .cursor:
            do {
                try config.add(named: resource.name, toJSONFile: URL.homeDirectory.appending(path: ".cursor/mcp.json"))
                Task { await model.refresh() }
            } catch {
                model.manager.failure = ManagerFailure(title: "Couldn't add \(resource.name) to Cursor", error: error)
            }
        case .claudeCode:
            if let command = config.claudeCommand(name: resource.name) {
                copy(command, for: agent)
            }
        default:
            copy(config.codexTOML(name: resource.name), for: agent)
        }
    }

    private func copy(_ text: String, for agent: AgentApp) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = agent
    }
}
