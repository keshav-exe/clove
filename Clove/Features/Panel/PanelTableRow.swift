import Foundation

enum PanelTableRow: Identifiable, Hashable {
    case header(id: String, title: String, count: Int)
    case skill(CatalogEntry)

    var id: String {
        switch self {
        case .header(let id, _, _):
            "header:\(id)"
        case .skill(let entry):
            "skill:\(entry.primary.id)"
        }
    }

    var skillID: Skill.ID? {
        switch self {
        case .header:
            nil
        case .skill(let entry):
            entry.primary.id
        }
    }

    static func rows(from sections: [SkillSection]) -> [PanelTableRow] {
        sections.flatMap { section in
            [.header(id: section.id, title: section.title, count: section.entries.count)]
                + section.entries.map { .skill($0) }
        }
    }
}
