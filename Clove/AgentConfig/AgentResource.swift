import Foundation

/// One instruction file, rule, command, subagent, MCP server, hook, or
/// permission rule found on this Mac.
struct AgentResource: Identifiable, Hashable, Sendable {
    let id: String
    let kind: ResourceKind
    let agent: AgentApp
    let scope: ResourceScope
    let name: String
    let summary: String
    /// The file that defines it. Several resources can share one config file.
    let fileURL: URL
    /// The entry inside a shared config file (an MCP server's name, a hook's
    /// event). Nil when the whole file is the resource.
    let configKey: String?
    var details: [ResourceDetail] = []
    /// Approximate tokens the agent loads every session, when it loads it at all.
    var tokens: Int?
    var modifiedAt: Date = .distantPast
    /// Something about it that is wrong on disk, like a hook script that's gone.
    var problem: String?

    /// The whole file is this resource, so it can be edited or trashed as one.
    var isFileBacked: Bool {
        configKey == nil
    }

    var isMarkdown: Bool {
        ["md", "mdc", "markdown"].contains(fileURL.pathExtension.lowercased())
    }

    /// The name the agent uses for it in transcripts, for usage tracking.
    var usageKey: String {
        switch kind {
        case .subagents: "agent:" + name
        case .mcpServers: "mcp:" + Self.normalizedServerName(name)
        default: name
        }
    }

    /// Whether Clove can see this being used. Transcripts only show Claude
    /// Code calling commands, subagents, and MCP servers, and server names
    /// repeat across agents, so another agent's server can't be judged.
    var hasObservableUsage: Bool {
        [.commands, .subagents, .mcpServers].contains(kind) && agent == .claudeCode
    }

    /// Claude Code turns a server's name into a tool prefix by replacing
    /// anything that isn't a letter, digit, hyphen, or underscore.
    static func normalizedServerName(_ name: String) -> String {
        String(name.map { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") ? $0 : "_" })
            .lowercased()
    }
}
