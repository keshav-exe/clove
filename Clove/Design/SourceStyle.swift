import SwiftUI

/// One code icon everywhere, tinted by source.
extension SkillSource {
    static let listIcon = "chevron.left.forwardslash.chevron.right"

    var symbolName: String {
        Self.listIcon
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
