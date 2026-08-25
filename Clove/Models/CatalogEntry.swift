import Foundation

/// One logical skill that may exist in several agent folders with the same reference.
struct CatalogEntry: Identifiable, Hashable, Sendable {
    var id: String { key }

    let key: String
    let primary: Skill
    let copies: [Skill]

    var isLinked: Bool {
        copies.count > 1
    }

    var sources: [SkillSource] {
        var seen: [SkillSource] = []
        for skill in copies where !seen.contains(skill.source) {
            seen.append(skill.source)
        }
        return seen.sorted()
    }

    var displayName: String {
        primary.displayName
    }

    var summary: String {
        primary.summary
    }

    var reference: String {
        primary.reference
    }
}

enum SkillCatalog {
    static func catalogKey(for skill: Skill) -> String {
        skill.reference + "\u{1e}" + (skill.sourceDetail ?? "")
    }

    static func build(from skills: [Skill]) -> [CatalogEntry] {
        var grouped: [String: [Skill]] = [:]
        grouped.reserveCapacity(skills.count)

        for skill in skills {
            grouped[catalogKey(for: skill), default: []].append(skill)
        }

        return grouped.map { key, copies in
            let sorted = copies.sorted { lhs, rhs in
                if lhs.source != rhs.source {
                    return lhs.source < rhs.source
                }
                return lhs.resolvedPath.localizedStandardCompare(rhs.resolvedPath) == .orderedAscending
            }
            return CatalogEntry(key: key, primary: sorted[0], copies: sorted)
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func entry(for skill: Skill, in catalog: [CatalogEntry]) -> CatalogEntry? {
        catalog.first { entry in
            entry.copies.contains { $0.id == skill.id }
        }
    }

    static func linkedSourceLabel(for sources: [SkillSource]) -> String {
        sources.map(\.sectionTitle).joined(separator: ", ")
    }
}
