import Foundation

/// Everything besides skills that changes how an agent behaves.
enum ResourceKind: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case instructions
    case rules
    case commands
    case subagents
    case mcpServers
    case hooks
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instructions: "Instructions"
        case .rules: "Rules"
        case .commands: "Commands"
        case .subagents: "Subagents"
        case .mcpServers: "MCP Servers"
        case .hooks: "Hooks"
        case .permissions: "Permissions"
        }
    }

    var singular: String {
        switch self {
        case .instructions: "instruction file"
        case .rules: "rule"
        case .commands: "command"
        case .subagents: "subagent"
        case .mcpServers: "MCP server"
        case .hooks: "hook"
        case .permissions: "permission"
        }
    }

    var symbolName: String {
        switch self {
        case .instructions: "text.document"
        case .rules: "list.bullet.rectangle"
        case .commands: "slash.circle"
        case .subagents: "person.2"
        case .mcpServers: "server.rack"
        case .hooks: "bolt.horizontal"
        case .permissions: "checkmark.shield"
        }
    }

    /// One line on what this kind is, for empty states and headers.
    var explanation: String {
        switch self {
        case .instructions:
            "CLAUDE.md, AGENTS.md, and GEMINI.md files. Agents read them at the start of every session."
        case .rules:
            "Cursor and Windsurf rules: guidance applied always, by file pattern, or when relevant."
        case .commands:
            "Saved prompts you run with a slash, like /review."
        case .subagents:
            "Specialist agents the main agent can hand work to."
        case .mcpServers:
            "Tools and data sources agents connect to over the Model Context Protocol."
        case .hooks:
            "Shell commands agents run automatically before or after their own actions."
        case .permissions:
            "Commands and tools agents may run without asking first."
        }
    }

    /// Kinds whose text sits in the agent's context in every session.
    var loadsIntoContext: Bool {
        switch self {
        case .instructions, .commands, .subagents: true
        case .rules, .mcpServers, .hooks, .permissions: false
        }
    }
}
