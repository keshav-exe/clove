import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case sources
    case shortcuts
    case privacy
    case license
    case about

    var id: String { rawValue }

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
        case .about: "info"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .sources: .blue
        case .shortcuts: .indigo
        case .privacy: .green
        case .license: .orange
        case .about: .teal
        }
    }
}
