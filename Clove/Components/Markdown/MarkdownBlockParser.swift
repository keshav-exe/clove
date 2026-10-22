import Foundation

enum MarkdownBlockParser {
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacing("\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        var blocks: [MarkdownBlock] = []
        var paragraph: [Substring] = []
        var index = 0

        func append(_ kind: MarkdownBlock.Kind) {
            blocks.append(MarkdownBlock(id: blocks.count, kind: kind))
        }

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let text = paragraph.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            append(.paragraph(MarkdownInline.render(text)))
            paragraph.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if let fence = fenceMarker(trimmed) {
                flushParagraph()
                let language = String(trimmed.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                var code: [Substring] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    code.append(lines[index])
                    index += 1
                }
                index += 1
                append(.code(language: language.isEmpty ? nil : language, text: code.joined(separator: "\n")))
                continue
            }

            if let (level, text) = heading(trimmed) {
                flushParagraph()
                append(.heading(level: level, text: MarkdownInline.render(text)))
                index += 1
                continue
            }

            if isRule(trimmed) {
                flushParagraph()
                append(.rule)
                index += 1
                continue
            }

            if trimmed.hasPrefix("|"), index + 1 < lines.count, isTableSeparator(lines[index + 1]) {
                flushParagraph()
                var rows = [cells(trimmed)]
                index += 2
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(cells(lines[index].trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                append(.table(rows: rows))
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quoted: [String] = []
                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespaces)
                    guard next.hasPrefix(">") else { break }
                    quoted.append(String(next.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                append(.quote(MarkdownInline.render(quoted.joined(separator: " "))))
                continue
            }

            if listItem(line) != nil {
                flushParagraph()
                var items: [RawListItem] = []
                while index < lines.count {
                    let next = lines[index]
                    if let item = listItem(next) {
                        items.append(item)
                    } else if !items.isEmpty,
                              !next.trimmingCharacters(in: .whitespaces).isEmpty,
                              next.first == " " || next.first == "\t" {
                        // An indented line continues the previous item.
                        items[items.count - 1].text += " " + next.trimmingCharacters(in: .whitespaces)
                    } else {
                        break
                    }
                    index += 1
                }
                append(.list(items.map {
                    MarkdownListItem(level: $0.level, marker: $0.marker, text: MarkdownInline.render($0.text))
                }))
                continue
            }

            paragraph.append(line)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    private static func fenceMarker(_ line: String) -> String? {
        if line.hasPrefix("```") { return "```" }
        if line.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private static func heading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        return (hashes, rest.trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.filter { $0 != " " }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func isTableSeparator(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.contains("-")
            && trimmed.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ line: String) -> [AttributedString] {
        var content = Substring(line)
        if content.hasPrefix("|") { content = content.dropFirst() }
        if content.hasSuffix("|") { content = content.dropLast() }
        return content
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { MarkdownInline.render($0.trimmingCharacters(in: .whitespaces)) }
    }

    private struct RawListItem {
        let level: Int
        let marker: String
        var text: String
    }

    private static func listItem(_ line: Substring) -> RawListItem? {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        let level = indent.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2
        let body = line.dropFirst(indent.count)

        var marker: String
        var rest: Substring
        if let first = body.first, "-*+".contains(first), body.dropFirst().first == " " {
            marker = "•"
            rest = body.dropFirst(2)
        } else {
            let digits = body.prefix { $0.isNumber }
            guard !digits.isEmpty, digits.count <= 3 else { return nil }
            let after = body.dropFirst(digits.count)
            guard let punctuation = after.first, punctuation == "." || punctuation == ")",
                  after.dropFirst().first == " " else { return nil }
            marker = "\(digits)."
            rest = after.dropFirst(2)
        }

        if rest.hasPrefix("[ ] ") {
            marker = "☐"
            rest = rest.dropFirst(4)
        } else if rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
            marker = "☑"
            rest = rest.dropFirst(4)
        }

        return RawListItem(level: min(level, 4), marker: marker, text: rest.trimmingCharacters(in: .whitespaces))
    }
}
