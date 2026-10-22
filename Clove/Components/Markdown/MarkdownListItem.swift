import Foundation

struct MarkdownListItem: Hashable, Sendable {
    /// Nesting depth, 0 for top-level items.
    let level: Int
    /// "•", "1.", or a checkbox glyph.
    let marker: String
    let text: AttributedString
}
