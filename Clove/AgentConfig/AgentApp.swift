import SwiftUI

/// The tool a configuration file belongs to.
enum AgentApp: String, CaseIterable, Identifiable, Hashable, Sendable, Codable, Comparable {
    case claudeCode
    case claudeDesktop
    case cursor
    case codex
    case gemini
    case copilot
    case windsurf
    /// AGENTS.md: read by Codex, Cursor, Copilot, and most others.
    case shared

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .claudeDesktop: "Claude Desktop"
        case .cursor: "Cursor"
        case .codex: "Codex"
        case .gemini: "Gemini"
        case .copilot: "Copilot"
        case .windsurf: "Windsurf"
        case .shared: "Any Agent"
        }
    }

    var tint: Color {
        switch self {
        case .claudeCode, .claudeDesktop: .orange
        case .cursor: .blue
        case .codex: .green
        case .gemini: .indigo
        case .copilot: .gray
        case .windsurf: .teal
        case .shared: .secondary
        }
    }

    static func < (lhs: AgentApp, rhs: AgentApp) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}
