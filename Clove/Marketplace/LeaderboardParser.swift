import Foundation

/// skills.sh has no public JSON endpoint for its leaderboards, but every
/// leaderboard page streams the list it renders as `initialSkills` inside the
/// React Server Components payload. This pulls that array back out.
enum LeaderboardParser {
    enum Failure: Error, Equatable {
        case missingPayload
        case malformedPayload
    }

    static func skills(fromHTML html: String) throws -> [MarketplaceSkill] {
        let payload = flightPayload(in: html)
        guard let array = jsonValue(after: "\"initialSkills\":", in: payload) else {
            throw Failure.missingPayload
        }
        do {
            return try JSONDecoder().decode([MarketplaceSkill].self, from: Data(array.utf8))
        } catch {
            throw Failure.malformedPayload
        }
    }

    /// Joins every `self.__next_f.push([1,"…"])` string chunk into one payload.
    static func flightPayload(in html: String) -> String {
        let marker = "self.__next_f.push([1,"
        var result = ""
        var searchStart = html.startIndex

        while let range = html.range(of: marker, range: searchStart..<html.endIndex) {
            guard let literal = stringLiteral(in: html, from: range.upperBound) else {
                searchStart = range.upperBound
                continue
            }
            if let decoded = try? JSONSerialization.jsonObject(
                with: Data(html[literal].utf8),
                options: .fragmentsAllowed
            ) as? String {
                result += decoded
            }
            searchStart = literal.upperBound
        }
        return result
    }

    /// The balanced JSON array or object that starts right after `key`.
    static func jsonValue(after key: String, in text: String) -> Substring? {
        guard let keyRange = text.range(of: key) else { return nil }
        let utf8 = text.utf8
        var index = keyRange.upperBound
        guard index < text.endIndex else { return nil }

        let open = utf8[index]
        guard open == UInt8(ascii: "[") || open == UInt8(ascii: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false

        while index < text.endIndex {
            let byte = utf8[index]
            if inString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
            } else {
                switch byte {
                case UInt8(ascii: "\""):
                    inString = true
                case UInt8(ascii: "["), UInt8(ascii: "{"):
                    depth += 1
                case UInt8(ascii: "]"), UInt8(ascii: "}"):
                    depth -= 1
                    if depth == 0 {
                        return text[keyRange.upperBound...index]
                    }
                default:
                    break
                }
            }
            index = utf8.index(after: index)
        }
        return nil
    }

    /// Range of a double-quoted JS string literal starting at `start`, quotes included.
    private static func stringLiteral(in text: String, from start: String.Index) -> Range<String.Index>? {
        let utf8 = text.utf8
        guard start < text.endIndex, utf8[start] == UInt8(ascii: "\"") else { return nil }

        var index = utf8.index(after: start)
        var escaped = false
        while index < text.endIndex {
            let byte = utf8[index]
            if escaped {
                escaped = false
            } else if byte == UInt8(ascii: "\\") {
                escaped = true
            } else if byte == UInt8(ascii: "\"") {
                return start..<utf8.index(after: index)
            }
            index = utf8.index(after: index)
        }
        return nil
    }
}
