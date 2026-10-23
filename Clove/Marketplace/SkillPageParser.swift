import Foundation

/// Reads the server-rendered skills.sh skill page. Every field is optional:
/// if the page layout changes, the detail view falls back to the SKILL.md alone.
enum SkillPageParser {
    static func details(fromHTML html: String) -> SkillPageDetails {
        let text = textLines(fromHTML: html)
        var details = SkillPageDetails()
        details.description = metaDescription(in: html)
        details.highlights = section(in: text, after: "Summary", until: ["SKILL.md"])
        details.gitHubStars = value(in: text, after: "GitHub Stars")
        details.firstSeen = value(in: text, after: "First Seen")
        details.audits = audits(in: text)
        details.renderedBody = section(in: text, after: "SKILL.md", until: ["Show more", "Installs"])
        return details
    }

    static func metaDescription(in html: String) -> String? {
        let marker = "<meta name=\"description\" content=\""
        guard
            let start = html.range(of: marker),
            let end = html.range(of: "\"", range: start.upperBound..<html.endIndex)
        else { return nil }
        let text = decodeEntities(String(html[start.upperBound..<end.lowerBound]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Visible text, one line per element, with scripts and styles removed.
    /// A byte scanner rather than regex: skill pages run close to a megabyte.
    static func textLines(fromHTML html: String) -> [String] {
        let bytes = Array(html.utf8)
        var lines: [String] = []
        var current: [UInt8] = []
        var index = 0

        func flush() {
            guard !current.isEmpty else { return }
            let line = decodeEntities(String(decoding: current, as: UTF8.self))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                lines.append(line)
            }
            current.removeAll(keepingCapacity: true)
        }

        while index < bytes.count {
            guard bytes[index] == UInt8(ascii: "<") else {
                current.append(bytes[index])
                index += 1
                continue
            }
            // Inline tags like <code> sit inside a sentence; breaking the line
            // there turned "use `npx skills find` to search" into three bullets.
            if !isInlineTag(in: bytes, at: index) {
                flush()
            }
            if let skipped = endOfRawElement(in: bytes, at: index) {
                index = skipped
                continue
            }
            while index < bytes.count, bytes[index] != UInt8(ascii: ">") {
                index += 1
            }
            index += 1
        }
        flush()
        return lines
    }

    private static let inlineTags: Set<String> = ["b", "code", "em", "i", "kbd", "mark", "small", "strong", "sub", "sup"]

    /// Whether the tag starting at `start` (opening or closing) is one of `inlineTags`.
    private static func isInlineTag(in bytes: [UInt8], at start: Int) -> Bool {
        var index = start + 1
        if index < bytes.count, bytes[index] == UInt8(ascii: "/") {
            index += 1
        }
        var name: [UInt8] = []
        while index < bytes.count, name.count < 8 {
            let byte = bytes[index]
            guard (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")) || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) else { break }
            name.append(byte | 0x20)
            index += 1
        }
        return inlineTags.contains(String(decoding: name, as: UTF8.self))
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return decodeNumericEntities(text)
            .replacing("&quot;", with: "\"")
            .replacing("&#x27;", with: "'")
            .replacing("&#39;", with: "'")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&nbsp;", with: " ")
            .replacing("&amp;", with: "&")
    }

    /// `&#x3C;` and `&#60;` style references, which pages use for any character.
    private static func decodeNumericEntities(_ text: String) -> String {
        guard text.contains("&#") else { return text }
        return text.replacing(/&#(x?)([0-9A-Fa-f]+);/) { match in
            let radix = match.output.1.isEmpty ? 10 : 16
            guard let value = UInt32(match.output.2, radix: radix), let scalar = Unicode.Scalar(value) else {
                return String(match.output.0)
            }
            return String(Character(scalar))
        }
    }

    /// For `<script>` and `<style>`, the index just past their closing tag.
    private static func endOfRawElement(in bytes: [UInt8], at start: Int) -> Int? {
        for name in ["script", "style"] {
            let open = Array("<\(name)".utf8)
            guard hasPrefix(bytes, open, at: start) else { continue }
            let close = Array("</\(name)>".utf8)
            var index = start + open.count
            while index < bytes.count {
                if hasPrefix(bytes, close, at: index) {
                    return index + close.count
                }
                index += 1
            }
            return bytes.count
        }
        return nil
    }

    private static func hasPrefix(_ bytes: [UInt8], _ prefix: [UInt8], at index: Int) -> Bool {
        guard index + prefix.count <= bytes.count else { return false }
        for offset in prefix.indices where bytes[index + offset] != prefix[offset] {
            return false
        }
        return true
    }

    private static func value(in lines: [String], after label: String) -> String? {
        guard let index = lines.firstIndex(of: label), index + 1 < lines.count else { return nil }
        return lines[index + 1]
    }

    private static func section(in lines: [String], after label: String, until stops: Set<String>) -> [String] {
        guard let start = lines.firstIndex(of: label) else { return [] }
        var collected: [String] = []
        for line in lines[(start + 1)...] {
            if stops.contains(line) { break }
            collected.append(line)
        }
        return collected
    }

    private static func audits(in lines: [String]) -> [SkillAudit] {
        guard let start = lines.firstIndex(of: "Security Audits") else { return [] }
        var audits: [SkillAudit] = []
        var index = start + 1
        while index + 1 < lines.count, audits.count < 8 {
            let audit = SkillAudit(provider: lines[index], status: lines[index + 1])
            guard audit.verdict != .unknown else { break }
            audits.append(audit)
            index += 2
        }
        return audits
    }
}
