import Foundation
import Testing
@testable import Clove

struct MarkdownBlockParserTests {
    @Test func parsesCommonBlocks() {
        let blocks = MarkdownBlockParser.blocks(from: """
        # Title

        First line
        continues here.

        - one
          wrapped
        - [x] done
        1. first

        ```swift
        let a = 1
        ```

        > quoted

        | A | B |
        |---|---|
        | 1 | 2 |

        ---
        """)

        guard blocks.count == 7 else {
            Issue.record("Expected 7 blocks, got \(blocks.count)")
            return
        }

        if case .heading(let level, let text) = blocks[0].kind {
            #expect(level == 1)
            #expect(String(text.characters) == "Title")
        } else { Issue.record("Expected heading") }

        if case .paragraph(let text) = blocks[1].kind {
            #expect(String(text.characters) == "First line continues here.")
        } else { Issue.record("Expected paragraph") }

        if case .list(let items) = blocks[2].kind {
            #expect(items.map(\.marker) == ["•", "☑", "1."])
            #expect(String(items[0].text.characters) == "one wrapped")
        } else { Issue.record("Expected list") }

        if case .code(let language, let text) = blocks[3].kind {
            #expect(language == "swift")
            #expect(text == "let a = 1")
        } else { Issue.record("Expected code") }

        if case .table(let rows) = blocks[5].kind {
            #expect(rows.count == 2)
        } else { Issue.record("Expected table") }

        if case .rule = blocks[6].kind {} else { Issue.record("Expected rule") }
    }

    @Test func keepsInlineStyling() {
        let blocks = MarkdownBlockParser.blocks(from: "Use **bold** and `code`.")
        guard case .paragraph(let text) = blocks.first?.kind else {
            Issue.record("Expected paragraph")
            return
        }
        #expect(String(text.characters) == "Use bold and code.")
    }
}
