import Foundation

/// One saved agent session on disk.
struct TranscriptFile: Hashable, Sendable {
    let url: URL
    let size: Int
    let modified: Date
}
