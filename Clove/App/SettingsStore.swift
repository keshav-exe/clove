import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    /// Menu-bar-only mode. Requires the menu bar icon, otherwise the app has no way back.
    var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: Keys.hideDockIcon) }
    }

    var keepPanelOnTop: Bool {
        didSet { defaults.set(keepPanelOnTop, forKey: Keys.keepPanelOnTop) }
    }

    var includePlugins: Bool {
        didSet { defaults.set(includePlugins, forKey: Keys.includePlugins) }
    }

    var includeProjects: Bool {
        didSet { defaults.set(includeProjects, forKey: Keys.includeProjects) }
    }

    var customProjectRoots: [String] {
        didSet { defaults.set(customProjectRoots, forKey: Keys.customProjectRoots) }
    }

    var hotKeyEnabled: Bool {
        didSet { defaults.set(hotKeyEnabled, forKey: Keys.hotKeyEnabled) }
    }

    var hotKey: KeyChord? {
        didSet { saveHotKey() }
    }

    var pinnedPanelFrame: String? {
        didSet { defaults.set(pinnedPanelFrame, forKey: Keys.pinnedPanelFrame) }
    }

    /// False when the system refused the shortcut, usually because another app owns it.
    var hotKeyIsRegistered = true

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
        showMenuBarIcon = defaults.flag(Keys.showMenuBarIcon, default: true)
        hideDockIcon = defaults.flag(Keys.hideDockIcon, default: false)
        keepPanelOnTop = defaults.flag(Keys.keepPanelOnTop, default: false)
        includePlugins = defaults.flag(Keys.includePlugins, default: true)
        includeProjects = defaults.flag(Keys.includeProjects, default: true)
        customProjectRoots = defaults.stringArray(forKey: Keys.customProjectRoots) ?? []
        hotKeyEnabled = defaults.flag(Keys.hotKeyEnabled, default: true)
        pinnedPanelFrame = defaults.string(forKey: Keys.pinnedPanelFrame)
        hotKey = Self.loadHotKey(from: defaults)
    }

    var scanConfiguration: ScanConfiguration {
        ScanConfiguration.make(
            includePlugins: includePlugins,
            includeProjects: includeProjects,
            customRoots: customProjectRoots.map { URL(filePath: $0) }
        )
    }

    var canHideDockIcon: Bool {
        showMenuBarIcon
    }

    func addProjectRoot(_ url: URL) {
        let path = url.path(percentEncoded: false)
        guard !customProjectRoots.contains(path) else { return }
        customProjectRoots.append(path)
    }

    func removeProjectRoot(_ path: String) {
        customProjectRoots.removeAll { $0 == path }
    }

    private func saveHotKey() {
        if let hotKey, let data = try? JSONEncoder().encode(hotKey) {
            defaults.set(data, forKey: Keys.hotKey)
        } else {
            defaults.set(Data(), forKey: Keys.hotKey)
        }
    }

    private static func loadHotKey(from defaults: UserDefaults) -> KeyChord? {
        guard let object = defaults.object(forKey: Keys.hotKey) else {
            return .default
        }
        guard let data = object as? Data, !data.isEmpty else {
            return nil
        }
        return try? JSONDecoder().decode(KeyChord.self, from: data)
    }

    private enum Keys {
        static let onboarded = "hasCompletedOnboarding"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let hideDockIcon = "hideDockIcon"
        static let keepPanelOnTop = "keepPanelOnTop"
        static let includePlugins = "includePlugins"
        static let includeProjects = "includeProjects"
        static let customProjectRoots = "customProjectRoots"
        static let hotKeyEnabled = "hotKeyEnabled"
        static let hotKey = "hotKey"
        static let pinnedPanelFrame = "pinnedPanelFrame"
    }
}

private extension UserDefaults {
    func flag(_ key: String, default fallback: Bool) -> Bool {
        object(forKey: key) == nil ? fallback : bool(forKey: key)
    }
}
