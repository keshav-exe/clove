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
        case .cursor: Palette.Vivid.blue
        case .cursorBuiltin: Palette.inkSecondary
        case .claude: Palette.Vivid.orange
        case .agents: Palette.Vivid.violet
        case .codex: Palette.Vivid.green
        case .plugin: Palette.Vivid.pink
        case .project: Palette.Vivid.yellow
        case .other: Palette.inkSecondary
        }
    }
}
