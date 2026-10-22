import Foundation

/// An editable SKILL.md: the two frontmatter fields every agent reads, the
/// rest of the frontmatter kept verbatim, and the markdown body.
struct SkillDocument: Equatable, Sendable {
    var name: String
    var description: String
    /// Frontmatter lines other than `name` and `description`, untouched.
    var extraFrontmatter: [String]
    var body: String

    init(name: String, description: String, extraFrontmatter: [String] = [], body: String) {
        self.name = name
        self.description = description
        self.extraFrontmatter = extraFrontmatter
        self.body = body
    }

    init(markdown: String) {
        let normalized = markdown.replacing("\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else {
            self.init(name: "", description: "", body: normalized)
            return
        }

        var known: [String] = []
        var extra: [String] = []
        var currentIsKnown = false
        for line in lines[1..<end] {
            let isContinuation = line.first == " " || line.first == "\t"
            if !isContinuation {
                let key = line.split(separator: ":", maxSplits: 1).first?
                    .trimmingCharacters(in: .whitespaces).lowercased()
                currentIsKnown = key == "name" || key == "description"
            }
            if currentIsKnown {
                known.append(line)
            } else {
                extra.append(line)
            }
        }

        let matter = SkillFrontmatterParser.parse("---\n" + known.joined(separator: "\n") + "\n---\n").0
        let body = lines[(end + 1)...].joined(separator: "\n").trimmingCharacters(in: .newlines)

        self.init(
            name: matter.name ?? "",
            description: matter.summary ?? "",
            extraFrontmatter: extra,
            body: body
        )
    }

    var markdown: String {
        var lines = ["---", "name: \(Self.yamlScalar(name))", "description: \(Self.yamlScalar(description))"]
        lines += extraFrontmatter.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        lines.append("---")
        let trimmedBody = body.trimmingCharacters(in: .newlines)
        return lines.joined(separator: "\n") + "\n\n" + trimmedBody + "\n"
    }

    /// Quotes a value only when YAML would read it as something else.
    static func yamlScalar(_ raw: String) -> String {
        let value = raw.replacing("\n", with: " ").trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return "\"\"" }

        let reserved: Set<String> = ["true", "false", "yes", "no", "on", "off", "null", "~"]
        let needsQuotes = value.contains(": ")
            || value.contains(" #")
            || value.hasSuffix(":")
            || value.first.map { "-?:,[]{}#&*!|>'\"%@`".contains($0) } == true
            || reserved.contains(value.lowercased())
            || Double(value) != nil
        guard needsQuotes else { return value }

        let escaped = value.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
