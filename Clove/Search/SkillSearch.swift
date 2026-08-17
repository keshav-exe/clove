import Foundation

enum SkillSearch {
    static func results(
        skills: [Skill],
        query: String,
        userTags: [String: [String]],
        activeTag: String?
    ) -> [Skill] {
        let filtered: [Skill]
        if let activeTag {
            filtered = skills.filter { skill in
                mergedTags(for: skill, userTags: userTags).contains { tag in
                    tag.localizedStandardCompare(activeTag) == .orderedSame
                }
            }
        } else {
            filtered = skills
        }

        return ranked(skills: filtered, query: query, userTags: userTags)
    }

    static func library(
        skills: [Skill],
        query: String,
        userTags: [String: [String]],
        filter: LibraryFilter
    ) -> [Skill] {
        let filtered: [Skill]
        switch filter {
        case .all:
            filtered = skills
        case .source(let source):
            filtered = skills.filter { $0.source == source }
        case .tag(let tag):
            filtered = skills.filter { skill in
                mergedTags(for: skill, userTags: userTags).contains {
                    $0.localizedStandardCompare(tag) == .orderedSame
                }
            }
        }

        return ranked(skills: filtered, query: query, userTags: userTags)
    }

    static func count(of filter: LibraryFilter, in skills: [Skill], userTags: [String: [String]]) -> Int {
        switch filter {
        case .all:
            skills.count
        case .source(let source):
            skills.count { $0.source == source }
        case .tag(let tag):
            skills.count { skill in
                mergedTags(for: skill, userTags: userTags).contains {
                    $0.localizedStandardCompare(tag) == .orderedSame
                }
            }
        }
    }

    static func sections(from skills: [Skill]) -> [SkillSection] {
        var grouped: [(SkillSource, String?, [Skill])] = []
        var index: [String: Int] = [:]

        for skill in skills {
            let key = skill.source.rawValue + "\u{1e}" + (skill.sourceDetail ?? "")
            if let existing = index[key] {
                grouped[existing].2.append(skill)
            } else {
                index[key] = grouped.count
                grouped.append((skill.source, skill.sourceDetail, [skill]))
            }
        }

        return grouped.map { source, detail, skills in
            SkillSection(source: source, detail: detail, skills: skills)
        }
    }

    static func mergedTags(for skill: Skill, userTags: [String: [String]]) -> [String] {
        var seen: [String] = []
        let combined = skill.frontmatterTags + (userTags[skill.id] ?? [])
        for tag in combined {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.contains(where: { $0.localizedStandardCompare(trimmed) == .orderedSame }) {
                continue
            }
            seen.append(trimmed)
        }
        return seen
    }

    static func tokenize(_ query: String) -> [String] {
        query
            .split { $0.isWhitespace || $0 == "," }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func fuzzyMatch(_ query: String, in text: String) -> Bool {
        let needle = Array(query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        let haystack = Array(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }

        var index = 0
        for character in haystack {
            if character == needle[index] {
                index += 1
                if index == needle.count {
                    return true
                }
            }
        }
        return false
    }

    private static func ranked(
        skills: [Skill],
        query: String,
        userTags: [String: [String]]
    ) -> [Skill] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return skills }

        let scored: [(Skill, Int)] = skills.compactMap { skill in
            let tags = mergedTags(for: skill, userTags: userTags)
            guard let score = score(skill: skill, tags: tags, tokens: tokens) else { return nil }
            return (skill, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.displayName.localizedStandardCompare(rhs.0.displayName) == .orderedAscending
            }
            .map(\.0)
    }

    private static func score(skill: Skill, tags: [String], tokens: [String]) -> Int? {
        var total = 0
        for token in tokens {
            guard let tokenScore = score(skill: skill, tags: tags, token: token) else {
                return nil
            }
            total += tokenScore
        }
        return total
    }

    private static func score(skill: Skill, tags: [String], token: String) -> Int? {
        let name = skill.displayName
        if name.localizedStandardCompare(token) == .orderedSame {
            return 100
        }
        if name.lowercased().hasPrefix(token.lowercased()) {
            return 80
        }
        if name.localizedStandardContains(token) {
            return 60
        }
        if tags.contains(where: { $0.localizedStandardCompare(token) == .orderedSame }) {
            return 70
        }
        if tags.contains(where: { $0.localizedStandardContains(token) }) {
            return 50
        }
        if skill.summary.localizedStandardContains(token) {
            return 30
        }
        if let detail = skill.sourceDetail, detail.localizedStandardContains(token) {
            return 20
        }
        if skill.source.sectionTitle.localizedStandardContains(token) {
            return 15
        }
        if skill.directoryName.localizedStandardContains(token) {
            return 12
        }
        if fuzzyMatch(token, in: name) {
            return 8
        }
        return nil
    }
}
