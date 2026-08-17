import Foundation

enum SkillSource: String, CaseIterable, Sendable, Comparable {
    case cursor
    case cursorBuiltin
    case claude
    case agents
    case codex
    case plugin
    case project
    case other

    var sectionTitle: String {
        switch self {
        case .cursor: "Cursor"
        case .cursorBuiltin: "Cursor Built-in"
        case .claude: "Claude"
        case .agents: "Agents"
        case .codex: "Codex"
        case .plugin: "Plugins"
        case .project: "Projects"
        case .other: "Other"
        }
    }

    var sortOrder: Int {
        switch self {
        case .cursor: 0
        case .cursorBuiltin: 1
        case .claude: 2
        case .agents: 3
        case .codex: 4
        case .plugin: 5
        case .project: 6
        case .other: 7
        }
    }

    static func < (lhs: SkillSource, rhs: SkillSource) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    static func classify(path: String, home: String) -> SkillSource {
        if path.contains("/.cursor/plugins/") {
            .plugin
        } else if path.contains("/.cursor/skills-cursor/") {
            .cursorBuiltin
        } else if isHomeSkill(path, home: home, folder: ".cursor/skills") {
            .cursor
        } else if isHomeSkill(path, home: home, folder: ".claude/skills") {
            .claude
        } else if isHomeSkill(path, home: home, folder: ".agents/skills") {
            .agents
        } else if isHomeSkill(path, home: home, folder: ".codex/skills") {
            .codex
        } else if path.contains("/.cursor/skills/")
            || path.contains("/.claude/skills/")
            || path.contains("/.agents/skills/")
            || path.contains("/.codex/skills/") {
            .project
        } else {
            .other
        }
    }

    static func detail(path: String, source: SkillSource) -> String? {
        switch source {
        case .plugin:
            pluginName(from: path)
        case .project:
            projectName(from: path)
        default:
            nil
        }
    }

    private static func isHomeSkill(_ path: String, home: String, folder: String) -> Bool {
        let prefix = home.hasSuffix("/") ? home + folder + "/" : home + "/" + folder + "/"
        return path.hasPrefix(prefix)
    }

    private static func pluginName(from path: String) -> String? {
        let marker = "/plugins/cache/"
        guard let markerRange = path.range(of: marker) else { return nil }
        let remainder = path[markerRange.upperBound...]
        let parts = remainder.split(separator: "/", maxSplits: 3)
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }

    private static func projectName(from path: String) -> String? {
        let markers = ["/.cursor/skills/", "/.claude/skills/", "/.agents/skills/", "/.codex/skills/"]
        guard let marker = markers.first(where: { path.contains($0) }) else { return nil }
        guard let range = path.range(of: marker) else { return nil }
        let before = String(path[..<range.lowerBound])
        return URL(filePath: before).lastPathComponent
    }
}
