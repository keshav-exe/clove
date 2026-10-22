import Foundation

/// A SKILL.md fetched from a skill's GitHub repository.
struct RemoteSkillFile: Hashable, Sendable {
    /// Path inside the repository, e.g. `skills/find-skills/SKILL.md`.
    let path: String
    let markdown: String

    /// Empty for a SKILL.md at the repository root.
    var folderPath: String {
        (path as NSString).deletingLastPathComponent
    }
}
