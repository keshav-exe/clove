import Foundation

/// What an uninstall changed on disk, so it can be undone.
struct TrashReceipt: Sendable {
    struct Move: Sendable {
        let original: URL
        let trashed: URL
    }

    struct Link: Sendable {
        let url: URL
        let destination: String
    }

    var moves: [Move] = []
    var links: [Link] = []
    var lockEntries: [SkillLockEntry] = []

    mutating func append(_ other: TrashReceipt) {
        moves += other.moves
        links += other.links
        lockEntries += other.lockEntries
    }
}
