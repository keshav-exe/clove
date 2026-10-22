import Foundation

/// A problem with a SKILL.md, checked against the Agent Skills format.
struct SkillDocumentIssue: Identifiable, Hashable, Sendable {
    enum Severity: Sendable {
        /// Agents may refuse to load the skill.
        case error
        /// Loads, but works worse than it could.
        case warning
    }

    var id: String { message }
    let severity: Severity
    let message: String

    static let nameLimit = 64
    static let descriptionLimit = 1024
    static let bodyLineGuide = 500

    static func issues(in document: SkillDocument, folderName: String?) -> [SkillDocumentIssue] {
        var issues: [SkillDocumentIssue] = []
        let name = document.name.trimmingCharacters(in: .whitespaces)
        let description = document.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty {
            issues.append(.init(severity: .error, message: "Add a name. Agents use it as the skill's reference."))
        } else {
            if name.count > nameLimit {
                issues.append(.init(severity: .error, message: "Keep the name under \(nameLimit) characters."))
            }
            if !isValidName(name) {
                issues.append(.init(
                    severity: .error,
                    message: "Use lowercase letters, numbers, and single hyphens in the name, like “release-notes”."
                ))
            }
            if let folderName, folderName != name {
                issues.append(.init(
                    severity: .warning,
                    message: "The name doesn't match its folder “\(folderName)”. Some agents look skills up by folder."
                ))
            }
        }

        if description.isEmpty {
            issues.append(.init(
                severity: .error,
                message: "Add a description. Agents read it to decide when to load the skill."
            ))
        } else if description.count > descriptionLimit {
            issues.append(.init(severity: .error, message: "Keep the description under \(descriptionLimit) characters."))
        } else if description.count < 40 {
            issues.append(.init(
                severity: .warning,
                message: "Say what the skill does and when to use it, so agents know when to reach for it."
            ))
        }

        let lineCount = document.body.count { $0 == "\n" } + 1
        if lineCount > bodyLineGuide {
            issues.append(.init(
                severity: .warning,
                message: "Over \(bodyLineGuide) lines. Move detail into reference files the skill links to."
            ))
        }
        return issues
    }

    /// Lowercase alphanumerics separated by single hyphens.
    static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("-"), !name.hasSuffix("-"), !name.contains("--") else { return false }
        return name.allSatisfy { ($0.isLetter && $0.isLowercase && $0.isASCII) || ($0.isNumber && $0.isASCII) || $0 == "-" }
    }

    /// Turns a typed title into a valid name: "Release Notes!" becomes "release-notes".
    static func slug(from title: String) -> String {
        var slug = ""
        for character in title.lowercased() {
            if (character.isLetter || character.isNumber) && character.isASCII {
                slug.append(character)
            } else if !slug.isEmpty, slug.last != "-" {
                slug.append("-")
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return String(slug.prefix(nameLimit))
    }
}
