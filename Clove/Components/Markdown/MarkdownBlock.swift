import Foundation

struct MarkdownBlock: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case heading(level: Int, text: AttributedString)
        case paragraph(AttributedString)
        case list([MarkdownListItem])
        case quote(AttributedString)
        case code(language: String?, text: String)
        case table(rows: [[AttributedString]])
        case rule
    }

    let id: Int
    let kind: Kind
}
