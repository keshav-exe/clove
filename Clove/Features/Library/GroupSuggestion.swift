import Foundation

enum GroupSuggestion: Identifiable, Hashable {
    case existing(String)
    case create(String)

    var id: String {
        switch self {
        case .existing(let name): "existing:\(name)"
        case .create(let name): "create:\(name)"
        }
    }

    var name: String {
        switch self {
        case .existing(let name), .create(let name):
            name
        }
    }

    /// Unassigned groups, filtered by the typed query. A create row appears
    /// when the query is not already a group this skill belongs to.
    static func matching(query: String, assigned: [String], available: [String]) -> [GroupSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let unassigned = available.filter { name in
            !assigned.contains { $0.localizedStandardCompare(name) == .orderedSame }
        }

        if trimmed.isEmpty {
            return unassigned.map { .existing($0) }
        }

        let matches = unassigned.filter { $0.localizedStandardContains(trimmed) }
        let alreadyUsed = assigned.contains { $0.localizedStandardCompare(trimmed) == .orderedSame }
            || matches.contains { $0.localizedStandardCompare(trimmed) == .orderedSame }

        var result = matches.map { GroupSuggestion.existing($0) }
        if !alreadyUsed {
            result.insert(.create(trimmed), at: 0)
        }
        return result
    }
}
