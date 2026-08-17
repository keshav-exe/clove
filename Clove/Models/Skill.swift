import Foundation

struct Skill: Identifiable, Hashable, Sendable {
    var id: String { resolvedPath }

    let name: String
    let summary: String
    /// Path as discovered while scanning. May be a symlink.
    let originalURL: URL
    /// Target file used for reading and opening in an editor.
    let fileURL: URL
    let resolvedPath: String
    let directoryName: String
    let source: SkillSource
    let sourceDetail: String?
    let frontmatterTags: [String]
    let modifiedAt: Date
    let isSymlink: Bool
    let installKind: SkillInstallKind

    var displayName: String {
        name.isEmpty ? directoryName : name
    }

    var reference: String {
        SkillReference.string(for: self)
    }
}
