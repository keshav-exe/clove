import Foundation

/// A skill, command, or subagent Cleanup suggests removing.
struct CleanupCandidate: Identifiable, Hashable, Sendable {
    enum Item: Hashable, Sendable {
        case skill(CatalogEntry)
        case resource(AgentResource)
    }

    let item: Item
    /// Nil when no transcript mentions it at all.
    let lastUsed: Date?
    let tokens: Int

    var id: String {
        switch item {
        case .skill(let entry): "skill:" + entry.id
        case .resource(let resource): resource.id
        }
    }

    var displayName: String {
        switch item {
        case .skill(let entry): entry.displayName
        case .resource(let resource): resource.kind == .commands ? "/" + resource.name : resource.name
        }
    }

    var kindTitle: String {
        switch item {
        case .skill: "Skill"
        case .resource(let resource): resource.kind == .commands ? "Command" : "Subagent"
        }
    }

    /// Agents list every installed skill's name and description in each
    /// session. Roughly four characters per token, plus list formatting.
    static func contextTokens(for entry: CatalogEntry) -> Int {
        let characters = entry.reference.count + entry.summary.count + 16
        return (characters + 3) / 4
    }

    /// Skills only in agent home folders, plus Claude Code's own commands and
    /// subagents, unused within the window. Plugin and project items aren't
    /// Clove's to remove, and anything added or edited inside the window
    /// hasn't had a chance to be used yet.
    static func candidates(
        in catalog: [CatalogEntry],
        resources: [AgentResource] = [],
        lastUsed: [String: Date],
        window: CleanupWindow,
        now: Date = .now
    ) -> [CleanupCandidate] {
        let cutoff = window.cutoff(from: now)

        let skills: [CleanupCandidate] = catalog.compactMap { entry in
            guard entry.copies.allSatisfy(\.source.isAgentHome) else { return nil }
            guard entry.copies.allSatisfy({ $0.modifiedAt < cutoff }) else { return nil }

            let skill = entry.primary
            let used = [skill.directoryName, skill.name].compactMap { lastUsed[$0] }.max()
            if let used, used >= cutoff { return nil }
            return CleanupCandidate(item: .skill(entry), lastUsed: used, tokens: contextTokens(for: entry))
        }

        // Only Claude Code's commands and subagents show up in transcripts.
        let others: [CleanupCandidate] = resources.compactMap { resource in
            guard [.commands, .subagents].contains(resource.kind),
                  resource.agent == .claudeCode,
                  resource.scope.isGlobal,
                  resource.isFileBacked,
                  resource.modifiedAt < cutoff
            else { return nil }
            let used = lastUsed[resource.usageKey]
            if let used, used >= cutoff { return nil }
            return CleanupCandidate(item: .resource(resource), lastUsed: used, tokens: resource.tokens ?? 0)
        }

        return (skills + others).sorted { lhs, rhs in
            // Never used first, then longest idle.
            switch (lhs.lastUsed, rhs.lastUsed) {
            case (nil, nil): lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case (nil, _): true
            case (_, nil): false
            case let (left?, right?): left < right
            }
        }
    }
}
