import Foundation

/// One folder or file an agent left behind.
struct LeftoverItem: Identifiable, Hashable, Sendable {
    var id: String { url.path(percentEncoded: false) }
    let kind: LeftoverKind
    let title: String
    let detail: String
    let url: URL
    let bytes: Int64
    /// Safe to remove now: an older build, an idle cache entry, a version not in use.
    let isOutdated: Bool
}
