import SwiftUI

extension SkillSource {
    /// Agent folders read as folders; plugins and projects get their own shape
    /// so the Locations list scans by icon as well as name.
    var symbolName: String {
        switch self {
        case .cursor, .claude, .agents, .codex, .other: "folder"
        case .cursorBuiltin: "shippingbox"
        case .plugin: "puzzlepiece.extension"
        case .project: "hammer"
        }
    }

    var tint: Color {
        switch self {
        case .cursor: .blue
        case .cursorBuiltin: .gray
        case .claude: .orange
        case .agents: .purple
        case .codex: .green
        case .plugin: .pink
        case .project: .yellow
        case .other: .secondary
        }
    }
}
