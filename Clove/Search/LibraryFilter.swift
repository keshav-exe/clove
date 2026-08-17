import Foundation

enum LibraryFilter: Hashable, Sendable {
    case all
    case source(SkillSource)
    case tag(String)

    var title: String {
        switch self {
        case .all: "All Skills"
        case .source(let source): source.sectionTitle
        case .tag(let tag): tag
        }
    }

    var symbolName: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .source: SkillSource.listIcon
        case .tag: "tag"
        }
    }
}
