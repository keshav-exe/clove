import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    /// Notch-only mode: the notch is always there to bring Clove back.
    var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: Keys.hideDockIcon) }
    }

    /// Closing the library window hides it and keeps Clove running in the notch.
    var keepRunningInMenuBar: Bool {
        didSet { defaults.set(keepRunningInMenuBar, forKey: Keys.keepRunningInMenuBar) }
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

    /// Group names created before any skill was added.
    var savedGroupNames: [String] {
        didSet { defaults.set(savedGroupNames, forKey: Keys.savedGroupNames) }
    }

    /// Where Clove lives: in the notch, or as a menu bar icon.
    var accessMode: AccessMode {
        didSet { defaults.set(accessMode.rawValue, forKey: Keys.accessMode) }
    }

    /// False until someone (or onboarding) picked a mode; upgraders from the
    /// menu bar era start here.
    var hasChosenAccessMode: Bool {
        defaults.object(forKey: Keys.accessMode) != nil
    }

    /// The number beside the menu bar icon, in menu bar mode.
    var menuBarStat: MenuBarStat {
        didSet { defaults.set(menuBarStat.rawValue, forKey: Keys.menuBarStat) }
    }

    /// Hovering the notch opens a glance at what's live.
    var notchOpensOnHover: Bool {
        didSet { defaults.set(notchOpensOnHover, forKey: Keys.notchOpensOnHover) }
    }

    /// The open island turns to Liquid Glass below the notch, instead of solid black.
    var notchGlass: Bool {
        didSet { defaults.set(notchGlass, forKey: Keys.notchGlass) }
    }

    /// The notch grows for a moment when an agent finishes a turn.
    var notchAgentMoments: Bool {
        didSet { defaults.set(notchAgentMoments, forKey: Keys.notchAgentMoments) }
    }

    /// ...when a dev server starts or stops.
    var notchServerMoments: Bool {
        didSet { defaults.set(notchServerMoments, forKey: Keys.notchServerMoments) }
    }

    /// ...when the disk runs low.
    var notchStorageMoments: Bool {
        didSet { defaults.set(notchStorageMoments, forKey: Keys.notchStorageMoments) }
    }

    /// The Now board's sections, in order. Leaving one out hides it.
    var nowSections: [NowSection] {
        didSet { defaults.set(nowSections.map(\.rawValue), forKey: Keys.nowSections) }
    }

    /// Which listening ports the Now board lists.
    var nowShowsDevServers: Bool {
        didSet { defaults.set(nowShowsDevServers, forKey: Keys.nowShowsDevServers) }
    }

    /// Ports apps keep open for themselves, like Raycast's on :7265.
    var nowShowsAppPorts: Bool {
        didSet { defaults.set(nowShowsAppPorts, forKey: Keys.nowShowsAppPorts) }
    }

    /// Ports macOS keeps open, like AirPlay Receiver on :5000 and :7000.
    var nowShowsSystemPorts: Bool {
        didSet { defaults.set(nowShowsSystemPorts, forKey: Keys.nowShowsSystemPorts) }
    }

    /// Apps whose ports you hid from the Now board, by `PortOwner.key`.
    var hiddenPortOwners: [String] {
        didSet { defaults.set(hiddenPortOwners, forKey: Keys.hiddenPortOwners) }
    }

    /// Claude and Codex plan limits in the Now board. Off until asked for,
    /// since it reads each agent's sign-in and asks its servers.
    var showsUsageLimits: Bool {
        didSet { defaults.set(showsUsageLimits, forKey: Keys.showsUsageLimits) }
    }

    /// The limits invitation was answered, either way.
    var dismissedUsageLimitsOffer: Bool {
        didSet { defaults.set(dismissedUsageLimitsOffer, forKey: Keys.dismissedUsageLimitsOffer) }
    }

    /// ...when a Claude or Codex limit is nearly used up.
    var notchLimitMoments: Bool {
        didSet { defaults.set(notchLimitMoments, forKey: Keys.notchLimitMoments) }
    }

    /// The blocks in the menu bar panel, in the order their tiles sit.
    var panelBlocks: [PanelBlock] {
        didSet { defaults.set(panelBlocks.map(\.rawValue), forKey: Keys.panelBlocks) }
    }

    /// The block the panel opens on: the last one picked.
    var panelBlock: PanelBlock {
        didSet { defaults.set(panelBlock.rawValue, forKey: Keys.panelBlock) }
    }

    /// Groups pinned to the quick access panel for one-click filtering.
    var pinnedGroups: [String] {
        didSet { defaults.set(pinnedGroups, forKey: Keys.pinnedGroups) }
    }

    /// Last app version for which the user saw the What's New sheet.
    var lastSeenWhatsNewVersion: String? {
        didSet { defaults.set(lastSeenWhatsNewVersion, forKey: Keys.lastSeenWhatsNewVersion) }
    }

    /// Update the user dismissed until a newer version ships.

    /// Agents a skill from skills.sh is linked into when installed.
    var installTargets: Set<AgentTarget> {
        didSet { defaults.set(installTargets.map(\.rawValue).sorted(), forKey: Keys.installTargets) }
    }

    /// False when the system refused the shortcut, usually because another app owns it.
    var hotKeyIsRegistered = true

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
        hideDockIcon = defaults.flag(Keys.hideDockIcon, default: true)
        keepRunningInMenuBar = defaults.flag(Keys.keepRunningInMenuBar, default: true)
        keepPanelOnTop = defaults.flag(Keys.keepPanelOnTop, default: false)
        includePlugins = defaults.flag(Keys.includePlugins, default: true)
        includeProjects = defaults.flag(Keys.includeProjects, default: true)
        customProjectRoots = defaults.stringArray(forKey: Keys.customProjectRoots) ?? []
        hotKeyEnabled = defaults.flag(Keys.hotKeyEnabled, default: true)
        pinnedPanelFrame = defaults.string(forKey: Keys.pinnedPanelFrame)
        savedGroupNames = defaults.stringArray(forKey: Keys.savedGroupNames) ?? []
        pinnedGroups = defaults.stringArray(forKey: Keys.pinnedGroups) ?? []
        var blocks = (defaults.stringArray(forKey: Keys.panelBlocks) ?? []).compactMap(PanelBlock.init(rawValue:))
        // Sets saved before the notch get Now once; taking it out later sticks.
        if !defaults.bool(forKey: Keys.offeredNowBlock) {
            if !blocks.isEmpty, !blocks.contains(.now) {
                blocks.insert(.now, at: 0)
                // didSet doesn't run in init, so save it here.
                defaults.set(blocks.map(\.rawValue), forKey: Keys.panelBlocks)
            }
            defaults.set(true, forKey: Keys.offeredNowBlock)
        }
        panelBlocks = blocks.isEmpty ? PanelBlock.defaults : Array(blocks.prefix(PanelBlock.maxTabs))
        panelBlock = defaults.string(forKey: Keys.panelBlock).flatMap(PanelBlock.init(rawValue:)) ?? .skills
        notchOpensOnHover = defaults.flag(Keys.notchOpensOnHover, default: true)
        accessMode = defaults.string(forKey: Keys.accessMode).flatMap(AccessMode.init(rawValue:)) ?? .notch
        menuBarStat = defaults.string(forKey: Keys.menuBarStat).flatMap(MenuBarStat.init(rawValue:)) ?? .none
        notchGlass = defaults.flag(Keys.notchGlass, default: true)
        notchAgentMoments = defaults.flag(Keys.notchAgentMoments, default: true)
        notchServerMoments = defaults.flag(Keys.notchServerMoments, default: true)
        notchStorageMoments = defaults.flag(Keys.notchStorageMoments, default: true)
        nowShowsDevServers = defaults.flag(Keys.nowShowsDevServers, default: true)
        nowSections = defaults.stringArray(forKey: Keys.nowSections).map { $0.compactMap(NowSection.init(rawValue:)) } ?? NowSection.defaults
        nowShowsAppPorts = defaults.flag(Keys.nowShowsAppPorts, default: true)
        nowShowsSystemPorts = defaults.flag(Keys.nowShowsSystemPorts, default: false)
        hiddenPortOwners = defaults.stringArray(forKey: Keys.hiddenPortOwners) ?? []
        showsUsageLimits = defaults.flag(Keys.showsUsageLimits, default: false)
        dismissedUsageLimitsOffer = defaults.flag(Keys.dismissedUsageLimitsOffer, default: false)
        notchLimitMoments = defaults.flag(Keys.notchLimitMoments, default: true)
        lastSeenWhatsNewVersion = defaults.string(forKey: Keys.lastSeenWhatsNewVersion)
        hotKey = Self.loadHotKey(from: defaults)
        installTargets = Self.loadInstallTargets(from: defaults)
    }

    var scanConfiguration: ScanConfiguration {
        ScanConfiguration.make(
            includePlugins: includePlugins,
            includeProjects: includeProjects,
            customRoots: customProjectRoots.map { URL(filePath: $0) }
        )
    }

    func addProjectRoot(_ url: URL) {
        let path = url.path(percentEncoded: false)
        guard !customProjectRoots.contains(path) else { return }
        customProjectRoots.append(path)
    }

    /// Whether the Now board lists a port, by your choices in Settings.
    func showsInNow(_ process: RunningProcess) -> Bool {
        if let owner = process.owner, hiddenPortOwners.contains(owner.key) { return false }
        switch process.kind {
        case .devServer: return nowShowsDevServers
        case .appPort: return process.owner?.isSystem == true ? nowShowsSystemPorts : nowShowsAppPorts
        case .agent, .mcpServer: return false
        }
    }

    func hidePorts(of owner: PortOwner) {
        guard !hiddenPortOwners.contains(owner.key) else { return }
        hiddenPortOwners.append(owner.key)
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

    /// Defaults to every agent that already has a folder in the home directory.
    private static func loadInstallTargets(from defaults: UserDefaults) -> Set<AgentTarget> {
        if let saved = defaults.stringArray(forKey: Keys.installTargets) {
            return Set(saved.compactMap(AgentTarget.init(rawValue:)))
        }
        let present = AgentTarget.allCases.filter { target in
            let agentHome = target.folder().deletingLastPathComponent()
            return FileManager.default.fileExists(atPath: agentHome.path(percentEncoded: false))
        }
        return present.isEmpty ? [.claude] : Set(present)
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
        static let hideDockIcon = "hideDockIcon"
        static let keepRunningInMenuBar = "keepRunningInMenuBar"
        static let keepPanelOnTop = "keepPanelOnTop"
        static let includePlugins = "includePlugins"
        static let includeProjects = "includeProjects"
        static let customProjectRoots = "customProjectRoots"
        static let hotKeyEnabled = "hotKeyEnabled"
        static let hotKey = "hotKey"
        static let pinnedPanelFrame = "pinnedPanelFrame"
        static let savedGroupNames = "savedGroupNames"
        static let pinnedGroups = "pinnedGroups"
        static let panelBlocks = "panelBlocks"
        static let panelBlock = "panelBlock"
        static let notchOpensOnHover = "notchOpensOnHover"
        static let accessMode = "accessMode"
        static let menuBarStat = "menuBarStat"
        static let offeredNowBlock = "offeredNowBlock"
        static let notchGlass = "notchGlass"
        static let notchAgentMoments = "notchAgentMoments"
        static let notchServerMoments = "notchServerMoments"
        static let notchStorageMoments = "notchStorageMoments"
        static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
        static let installTargets = "installTargets"
        static let nowShowsDevServers = "nowShowsDevServers"
        static let nowSections = "nowSections"
        static let nowShowsAppPorts = "nowShowsAppPorts"
        static let nowShowsSystemPorts = "nowShowsSystemPorts"
        static let hiddenPortOwners = "hiddenPortOwners"
        static let showsUsageLimits = "showsUsageLimits"
        static let dismissedUsageLimitsOffer = "dismissedUsageLimitsOffer"
        static let notchLimitMoments = "notchLimitMoments"
    }
}

private extension UserDefaults {
    func flag(_ key: String, default fallback: Bool) -> Bool {
        object(forKey: key) == nil ? fallback : bool(forKey: key)
    }
}
