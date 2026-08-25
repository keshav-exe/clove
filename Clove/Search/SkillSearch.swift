import Foundation

enum SkillSearch {
    static func results(
        catalog: [CatalogEntry],
        query: String,
        userTags: [String: [String]],
        activeTag: String?
    ) -> [CatalogEntry] {
        let filtered: [CatalogEntry]
        if let activeTag {
            filtered = catalog.filter { entry in
                mergedTags(for: entry, userTags: userTags).contains { tag in
                    tag.localizedStandardCompare(activeTag) == .orderedSame
                }
            }
        } else {
            filtered = catalog
        }

        return ranked(catalog: filtered, query: query, userTags: userTags)
    }

    static func library(
        catalog: [CatalogEntry],
        query: String,
        userTags: [String: [String]],
        filter: LibraryFilter
    ) -> [CatalogEntry] {
        let filtered: [CatalogEntry]
        switch filter {
        case .all:
            filtered = catalog
        case .source(let source):
            filtered = catalog.filter { entry in
                entry.copies.contains { $0.source == source }
            }
        case .tag(let tag):
            filtered = catalog.filter { entry in
                mergedTags(for: entry, userTags: userTags).contains {
                    $0.localizedStandardCompare(tag) == .orderedSame
                }
            }
        }

        return ranked(catalog: filtered, query: query, userTags: userTags)
    }

    static func count(of filter: LibraryFilter, in catalog: [CatalogEntry], userTags: [String: [String]]) -> Int {
        switch filter {
        case .all:
            catalog.count
        case .source(let source):
            catalog.count { entry in
                entry.copies.contains { $0.source == source }
            }
        case .tag(let tag):
            catalog.count { entry in
                mergedTags(for: entry, userTags: userTags).contains {
                    $0.localizedStandardCompare(tag) == .orderedSame
                }
            }
        }
    }

    static func sections(from catalog: [CatalogEntry]) -> [SkillSection] {
        var grouped: [(SkillSource, String?, [CatalogEntry])] = []
        var index: [String: Int] = [:]

        for entry in catalog {
            let source = entry.primary.source
            let detail = entry.primary.sourceDetail
            let key = source.rawValue + "\u{1e}" + (detail ?? "")
            if let existing = index[key] {
                grouped[existing].2.append(entry)
            } else {
                index[key] = grouped.count
                grouped.append((source, detail, [entry]))
            }
        }

        return grouped.map { source, detail, entries in
            SkillSection(source: source, detail: detail, entries: entries)
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

    static func mergedTags(for entry: CatalogEntry, userTags: [String: [String]]) -> [String] {
        var seen: [String] = []
        for skill in entry.copies {
            for tag in mergedTags(for: skill, userTags: userTags) {
                if seen.contains(where: { $0.localizedStandardCompare(tag) == .orderedSame }) {
                    continue
                }
                seen.append(tag)
            }
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
        catalog: [CatalogEntry],
        query: String,
        userTags: [String: [String]]
    ) -> [CatalogEntry] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return catalog }

        let scored: [(CatalogEntry, Int)] = catalog.compactMap { entry in
            let tags = mergedTags(for: entry, userTags: userTags)
            guard let score = score(entry: entry, tags: tags, tokens: tokens) else { return nil }
            return (entry, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.displayName.localizedStandardCompare(rhs.0.displayName) == .orderedAscending
            }
            .map(\.0)
    }

    private static func score(entry: CatalogEntry, tags: [String], tokens: [String]) -> Int? {
        var total = 0
        for token in tokens {
            guard let tokenScore = score(entry: entry, tags: tags, token: token) else {
                return nil
            }
            total += tokenScore
        }
        return total
    }

    private static func score(entry: CatalogEntry, tags: [String], token: String) -> Int? {
        let skill = entry.primary
        let name = entry.displayName
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
        if entry.summary.localizedStandardContains(token) {
            return 30
        }
        if entry.isLinked, SkillCatalog.linkedSourceLabel(for: entry.sources).localizedStandardContains(token) {
            return 25
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
