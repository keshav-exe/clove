import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case sources
    case shortcuts
    case privacy
    case license
    case about

    var id: String { rawValue }

    /// Sidebar entries for the current release channel.
    static var visibleCases: [SettingsPane] {
        var panes: [SettingsPane] = [.general, .sources, .shortcuts, .privacy]
        if ReleaseConfiguration.requiresLicense {
            panes.append(.license)
        }
        panes.append(.about)
        return panes
    }

    var title: String {
        switch self {
        case .general: "General"
        case .sources: "Sources"
        case .shortcuts: "Shortcuts"
        case .privacy: "Privacy"
        case .license: "License"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .sources: "folder"
        case .shortcuts: "keyboard"
        case .privacy: "lock.shield"
        case .license: "key"
        case .about: "info.circle"
        }
    }
}
