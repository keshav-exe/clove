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

    /// What shapes what an agent knows, and what shapes what it can do.
    static let contextKinds: [ResourceKind] = [.instructions, .rules, .commands, .subagents]
    static let toolKinds: [ResourceKind] = [.mcpServers, .hooks, .permissions]

    var title: String {
        switch self {
        case .instructions: "Instructions"
        case .rules: "Rules"
        case .commands: "Slash Commands"
        case .subagents: "Subagents"
        case .mcpServers: "MCP Servers"
        case .hooks: "Hooks"
        case .permissions: "Permissions"
        }
    }

    /// Short enough to fit under the window title.
    var subtitle: String {
        switch self {
        case .instructions: "CLAUDE.md, AGENTS.md, and GEMINI.md"
        case .rules: "Cursor, Windsurf, and Copilot rules"
        case .commands: "Saved prompts you run with /"
        case .subagents: "Specialists your agent hands work to"
        case .mcpServers: "Extra tools your agents can call"
        case .hooks: "Scripts that run on agent events"
        case .permissions: "What runs without asking you"
        }
    }

    var singular: String {
        switch self {
        case .instructions: "instruction file"
        case .rules: "rule"
        case .commands: "slash command"
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
        case .hooks: "bolt"
        case .permissions: "checkmark.shield"
        }
    }

    /// What this is and an example, for empty states.
    var explanation: String {
        switch self {
        case .instructions:
            "Notes your agents read at the start of every session, like how to run tests or which patterns to follow."
        case .rules:
            "Guidance an agent follows always, for certain files, or when it decides the rule is relevant."
        case .commands:
            "Prompts you save once and run with a slash, like /review or /release-notes."
        case .subagents:
            "Focused agents the main agent can hand a task to, like a code reviewer or a test writer."
        case .mcpServers:
            "Servers that give agents extra tools, like a browser, Figma, GitHub, or your database."
        case .hooks:
            "Commands that run on their own before or after an agent acts, like formatting a file after every edit."
        case .permissions:
            "Commands and tools an agent may run without stopping to ask you first."
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
