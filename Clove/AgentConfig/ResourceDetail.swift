import Foundation

/// One labeled fact about a resource, safe to show: secrets are already masked.
struct ResourceDetail: Hashable, Sendable {
    let label: String
    let value: String
    /// Code-like values (commands, globs, URLs) render in a monospaced face.
    var isCode = false
}
