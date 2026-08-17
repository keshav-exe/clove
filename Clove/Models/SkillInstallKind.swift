import Foundation

enum SkillInstallKind: String, Sendable {
    /// Linked into an agent skills folder from somewhere else.
    case homeSymlink
    /// Lives directly inside an agent skills folder.
    case homeLocal
    /// Checked into a repository under `.cursor/skills`, etc.
    case project
    /// Shipped inside a Cursor plugin cache folder.
    case plugin
    case other

    static func classify(source: SkillSource, isSymlink: Bool) -> SkillInstallKind {
        switch source {
        case .project:
            .project
        case .plugin:
            .plugin
        case .other:
            .other
        default:
            isSymlink ? .homeSymlink : .homeLocal
        }
    }
}
