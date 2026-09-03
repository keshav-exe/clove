import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case privacy
    case permissions
    case folders
    case features
    case shortcut

    var id: Int { rawValue }

    var symbolName: String {
        switch self {
        case .welcome: "sparkles"
        case .privacy: "lock.shield"
        case .permissions: "hand.raised"
        case .folders: "folder"
        case .features: "square.grid.2x2"
        case .shortcut: "command"
        }
    }

    var title: String {
        switch self {
        case .welcome: "Welcome to Clove"
        case .privacy: "Everything stays on this Mac"
        case .permissions: "One permission to set up"
        case .folders: "Where Clove looks"
        case .features: "Groups and skill actions"
        case .shortcut: "One shortcut away"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "Every agent skill installed on your Mac, in one searchable place."
        case .privacy:
            "Clove reads local files only. Nothing is uploaded or synced."
        case .permissions:
            "Accessibility lets Clove drop skills straight into your editor."
        case .folders:
            "These are the folders Clove will read. Nothing is opened until you finish setup."
        case .features:
            "Organize skills into groups and use the toolbar actions in the detail view."
        case .shortcut:
            "Call up the quick access panel from any app, then pin it beside your editor."
        }
    }

    /// The folder list reads better end to end, so that step gets a wider column.
    var contentWidth: Double {
        self == .folders ? 540 : 460
    }

    var continueTitle: String {
        self == .shortcut ? "Scan and Start" : "Continue"
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}
