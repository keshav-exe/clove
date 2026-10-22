import Foundation

/// A SKILL.md body split into blocks, with inline styling resolved up front so
/// rendering is a plain walk over values. Covers what skills actually use:
/// headings, paragraphs, lists, quotes, fenced code, tables, and rules.
struct MarkdownDocument: Hashable, Sendable {
    let blocks: [MarkdownBlock]

    init(_ markdown: String) {
        blocks = MarkdownBlockParser.blocks(from: markdown)
    }

    /// Plain paragraphs, for text that was already rendered elsewhere.
    init(paragraphs: [String]) {
        blocks = paragraphs.enumerated().map { index, text in
            MarkdownBlock(id: index, kind: .paragraph(MarkdownInline.render(text)))
        }
    }

    var isEmpty: Bool {
        blocks.isEmpty
    }
}
