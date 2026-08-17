import Foundation

struct SkillFrontmatter: Equatable, Sendable {
    var name: String?
    var summary: String?
    var tags: [String] = []
}

enum SkillFrontmatterParser {
    static func parse(_ markdown: String) -> (SkillFrontmatter, String) {
        let normalized = markdown.replacing("\r\n", with: "\n")
        guard normalized.hasPrefix("---") else {
            return (SkillFrontmatter(summary: extractFallbackSummary(from: normalized)), normalized)
        }

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (SkillFrontmatter(summary: extractFallbackSummary(from: normalized)), normalized)
        }

        var endIndex: Int?
        for index in 1..<lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces) == "---" {
                endIndex = index
                break
            }
        }

        guard let endIndex else {
            return (SkillFrontmatter(summary: extractFallbackSummary(from: normalized)), normalized)
        }

        let frontmatterLines = Array(lines[1..<endIndex])
        let body = lines[(endIndex + 1)...].joined(separator: "\n")
        var matter = parseFields(frontmatterLines)
        if matter.summary == nil {
            matter.summary = extractFallbackSummary(from: body)
        }
        return (matter, body)
    }

    static func extractFallbackSummary(from markdown: String) -> String? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        var paragraphs: [String] = []
        var current: [String] = []

        func flush() {
            let text = current.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                paragraphs.append(text)
            }
            current.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
                continue
            }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("```") || trimmed.hasPrefix("---") {
                flush()
                continue
            }
            current.append(trimmed)
        }
        flush()

        guard let first = paragraphs.first else { return nil }
        return stripMarkdown(first)
    }

    private static func parseFields(_ lines: [String]) -> SkillFrontmatter {
        var matter = SkillFrontmatter()
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let indent = leadingSpaces(line)
            if indent > 0 {
                index += 1
                continue
            }

            guard let colon = trimmed.firstIndex(of: ":") else {
                index += 1
                continue
            }

            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            var remainder = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            index += 1

            if remainder == ">" || remainder == ">-" || remainder == "|" || remainder == "|-"
                || (remainder.isEmpty && key != "tags") {
                let (block, next) = consumeIndentedBlock(lines, from: index)
                index = next
                remainder = remainder.isEmpty ? block.replacing("\n", with: " ") : block
            }

            switch key {
            case "name":
                matter.name = unquote(remainder)
            case "description":
                matter.summary = unquote(remainder.replacing("\n", with: " "))
            case "tags":
                matter.tags = parseTags(remainder, remainingLines: lines, index: &index)
            default:
                continue
            }
        }

        matter.name = matter.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        matter.summary = matter.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if matter.name?.isEmpty == true { matter.name = nil }
        if matter.summary?.isEmpty == true { matter.summary = nil }
        return matter
    }

    private static func parseTags(_ remainder: String, remainingLines: [String], index: inout Int) -> [String] {
        let trimmed = remainder.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") {
            return splitList(trimmed)
        }
        if !trimmed.isEmpty {
            return splitList(trimmed)
        }

        var tags: [String] = []
        while index < remainingLines.count {
            let line = remainingLines[index]
            let indent = leadingSpaces(line)
            let value = line.trimmingCharacters(in: .whitespaces)
            if indent == 0 && !value.isEmpty && !value.hasPrefix("-") {
                break
            }
            index += 1
            if value.hasPrefix("-") {
                let tag = unquote(String(value.dropFirst()).trimmingCharacters(in: .whitespaces))
                if !tag.isEmpty {
                    tags.append(tag)
                }
            }
        }
        return tags
    }

    private static func consumeIndentedBlock(_ lines: [String], from start: Int) -> (String, Int) {
        var index = start
        var collected: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if collected.isEmpty {
                    index += 1
                    continue
                }
                break
            }
            if leadingSpaces(line) == 0 {
                break
            }
            collected.append(line.trimmingCharacters(in: .whitespaces))
            index += 1
        }
        return (collected.joined(separator: "\n"), index)
    }

    private static func splitList(_ raw: String) -> [String] {
        var text = raw
        if text.hasPrefix("[") && text.hasSuffix("]") {
            text = String(text.dropFirst().dropLast())
        }
        return text
            .split(separator: ",")
            .map { unquote(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
    }

    private static func unquote(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if (text.hasPrefix("\"") && text.hasSuffix("\"") && text.count >= 2)
            || (text.hasPrefix("'") && text.hasSuffix("'") && text.count >= 2) {
            text = String(text.dropFirst().dropLast())
        }
        return text
    }

    private static func leadingSpaces(_ line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacing(/\*\*(.+?)\*\*/, with: { $0.output.1 })
        result = result.replacing(/\*(.+?)\*/, with: { $0.output.1 })
        result = result.replacing(/`(.+?)`/, with: { $0.output.1 })
        result = result.replacing(/\[(.+?)\]\(.+?\)/, with: { $0.output.1 })
        return result
    }
}
