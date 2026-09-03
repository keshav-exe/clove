import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case sources
    case shortcuts
    case privacy
    case about

    var id: String { rawValue }

    static var visibleCases: [SettingsPane] { allCases }

    var title: String {
        switch self {
        case .general: "General"
        case .sources: "Sources"
        case .shortcuts: "Shortcuts"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .sources: "folder"
        case .shortcuts: "keyboard"
        case .privacy: "lock.shield"
        case .about: "info.circle"
        }
    }
}
