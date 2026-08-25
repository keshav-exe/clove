import Foundation

struct SkillSection: Identifiable, Hashable, Sendable {
    var id: String { source.rawValue + (detail ?? "") }

    let source: SkillSource
    let detail: String?
    let entries: [CatalogEntry]

    var skills: [Skill] {
        entries.map(\.primary)
    }

    var title: String {
        if let detail, source == .plugin || source == .project {
            "\(source.sectionTitle) · \(detail)"
        } else {
            source.sectionTitle
        }
    }
}
