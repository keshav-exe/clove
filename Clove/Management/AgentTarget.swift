import Foundation

/// An agent whose skills folder Clove can link a skill into.
///
/// Installs follow the `skills` CLI layout: one real copy in `~/.agents/skills`,
/// symlinked into each agent's own folder, so both tools see the same files.
enum AgentTarget: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case claude
    case cursor
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: "Claude Code"
        case .cursor: "Cursor"
        case .codex: "Codex"
        }
    }

    var source: SkillSource {
        switch self {
        case .claude: .claude
        case .cursor: .cursor
        case .codex: .codex
        }
    }

    var relativeFolder: String {
        switch self {
        case .claude: ".claude/skills"
        case .cursor: ".cursor/skills"
        case .codex: ".codex/skills"
        }
    }

    func folder(home: URL = .homeDirectory) -> URL {
        home.appending(path: relativeFolder, directoryHint: .isDirectory)
    }

    static func sharedFolder(home: URL = .homeDirectory) -> URL {
        home.appending(path: ".agents/skills", directoryHint: .isDirectory)
    }
}
