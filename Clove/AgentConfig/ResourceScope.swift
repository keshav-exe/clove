import Foundation

/// Whether a resource applies everywhere or inside one project.
enum ResourceScope: Hashable, Sendable, Comparable {
    case global
    case project(String)

    var title: String {
        switch self {
        case .global: "Everywhere"
        case .project(let name): name
        }
    }

    var isGlobal: Bool {
        self == .global
    }

    static func < (lhs: ResourceScope, rhs: ResourceScope) -> Bool {
        switch (lhs, rhs) {
        case (.global, .global): false
        case (.global, .project): true
        case (.project, .global): false
        case let (.project(left), .project(right)): left.localizedStandardCompare(right) == .orderedAscending
        }
    }
}
