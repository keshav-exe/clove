import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    lazy var updates = UpdateService()

    private var notch: NotchController?
    private var live: NotchLiveMonitor?
    private let hotKeys = HotKeyCenter()
    private let menu = CloveMenu()
    /// Menu bar mode only.
    private var statusItem: StatusItemController?
    private var panel: PanelController?
    private var island: NotchModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let island = NotchModel(agents: AgentActivityStore(), settings: model.settings)
        self.island = island
        let notch = NotchController(model: model, notch: island, menu: menu)
        notch.onLocked = {
            NSApp.activate()
            LibraryWindowTracker.shared.showLibraryWindow()
        }
        configureMenu(menu)
        self.notch = notch

        let live = NotchLiveMonitor(model: model, notch: island)
        live.openStorage = { [weak self] in self?.openPanel(on: .storage) }
        self.live = live

        WindowBridge.shared.toggleQuickPanel = { [weak self] in
            self?.togglePanel()
        }

        hotKeys.handler = { [weak self] in
            self?.togglePanel()
        }
        WindowBridge.shared.suspendHotKey = { [weak self] suspended in
            guard let self else { return }
            if suspended {
                hotKeys.unregister()
            } else {
                applyHotKey()
            }
        }

        // Upgrading from the menu bar era: take the notch, unless another
        // notch app already has it. What's New shows the choice either way.
        if model.settings.hasCompletedOnboarding, !model.settings.hasChosenAccessMode {
            model.settings.accessMode = NotchNeighbors.suggestedMode
        }

        applySettings()
        watchSettings()
        InsertTarget.startObserving()
        updates.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(libraryWindowVisibilityChanged),
            name: .libraryWindowVisibilityDidChange,
            object: nil
        )

        NSApp.activate()

        #if DEBUG
        // `-panelPreview <block>`: open the panel pinned on a block, for screenshots.
        if let index = CommandLine.arguments.firstIndex(of: "-panelPreview") {
            let name = CommandLine.arguments.indices.contains(index + 1) ? CommandLine.arguments[index + 1] : ""
            let block = PanelBlock(rawValue: name)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.notch?.setPinned(true)
                self?.panel?.setPinned(true)
                self?.openPanel(on: block)
            }
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LibraryWindowTracker.shared.showLibraryWindow()
        return true
    }

    @objc private func libraryWindowVisibilityChanged() {
        applyActivationPolicy()
    }

    // MARK: - Settings

    private func applySettings() {
        let settings = model.settings
        LibraryWindowTracker.shared.keepRunningInMenuBar = settings.keepRunningInMenuBar
        applyActivationPolicy()
        applyHotKey()
        applyMode()
        if settings.hasCompletedOnboarding {
            live?.start()
        } else {
            live?.stop()
        }
    }

    private func applyActivationPolicy() {
        let settings = model.settings
        let wantsMenuBar = LibraryWindowTracker.shared.isLibraryVisible
            || hasVisibleRegularWindow

        let next: NSApplication.ActivationPolicy
        if !settings.hasCompletedOnboarding {
            next = .regular
        } else if wantsMenuBar {
            // Library/settings must own the menu bar or Clove → Settings never exists.
            next = .regular
        } else if settings.hideDockIcon || settings.keepRunningInMenuBar {
            next = .accessory
        } else {
            next = .regular
        }

        guard NSApp.activationPolicy() != next else { return }
        NSApp.setActivationPolicy(next)
        if next == .regular {
            NSApp.activate()
        }
    }

    private var hasVisibleRegularWindow: Bool {
        NSApp.windows.contains { window in
            guard window.isVisible, window.canBecomeKey else { return false }
            if window is NSPanel { return false }
            if window === WindowBridge.shared.panelWindow { return false }
            return true
        }
    }

    // MARK: - Mode

    /// Shows Clove where you chose: the notch, or an icon and panel in the
    /// menu bar. Switching takes effect at once; the other one is torn down.
    private func applyMode() {
        let settings = model.settings
        let onboarded = settings.hasCompletedOnboarding
        switch settings.accessMode {
        case .notch:
            statusItem?.remove()
            statusItem = nil
            panel?.tearDown()
            panel = nil
            statTask?.cancel()
            notch?.setPinned(settings.keepPanelOnTop)
            notch?.setVisible(onboarded)
        case .menuBar:
            notch?.setVisible(false)
            guard onboarded else { return }
            if panel == nil, let island {
                panel = PanelController(model: model, notch: island)
            }
            panel?.setPinned(settings.keepPanelOnTop)
            if statusItem == nil {
                let item = StatusItemController(menu: menu)
                item.onToggle = { [weak self] in self?.togglePanel() }
                statusItem = item
            }
            applyMenuBarStat()
        }
    }

    private var statTask: Task<Void, Never>?

    /// Refreshes the number beside the icon on the stat's own schedule. Nothing
    /// runs when the icon is shown alone.
    private func applyMenuBarStat() {
        statTask?.cancel()
        let stat = model.settings.menuBarStat
        guard stat != .none, let item = statusItem else {
            statusItem?.setStat(nil)
            return
        }
        statTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let reading = await stat.reading(known: self.model.knownServers)
                guard !Task.isCancelled else { return }
                item.setStat(reading)
                try? await Task.sleep(for: stat.interval)
            }
        }
    }

    private func openPanel(on block: PanelBlock?) {
        switch model.settings.accessMode {
        case .notch:
            notch?.open(block)
        case .menuBar:
            if let block, model.settings.panelBlocks.contains(block) { model.settings.panelBlock = block }
            panel?.show(relativeTo: statusItem?.button)
        }
    }

    /// The right-click menu on the notch or the icon: every section, like the sidebar.
    private func configureMenu(_ menu: CloveMenu) {
        menu.onOpenPanel = { [weak self] in
            self?.togglePanel()
        }
        menu.onShow = { [weak self] destination in
            self?.notch?.close()
            self?.panel?.hide()
            NSApp.activate()
            WindowBridge.shared.showLibraryWindow()
            self?.model.show(destination)
        }
        menu.onSettings = { [weak self] in
            self?.notch?.close()
            self?.panel?.hide()
            WindowBridge.shared.showSettings()
        }
        menu.onCheckForUpdates = { [weak self] in
            self?.updates.checkNow()
        }
        menu.panelShortcut = { [weak self] in
            guard let settings = self?.model.settings, settings.hotKeyEnabled else { return nil }
            return settings.hotKey
        }
        menu.badge = { [weak self] destination in
            guard let model = self?.model else { return nil }
            switch destination {
            case .cleanup:
                let count = model.cleanupCandidates.count
                return count == 0 ? nil : count.formatted(.number)
            case .storage:
                return model.storage.recommendation.map { StorageFormat.gb(model.storage.clearableBytes(for: $0)) }
            default:
                return nil
            }
        }
        menu.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func applyHotKey() {
        let settings = model.settings
        if settings.hotKeyEnabled, let chord = settings.hotKey {
            settings.hotKeyIsRegistered = hotKeys.register(chord)
        } else {
            hotKeys.unregister()
            settings.hotKeyIsRegistered = true
        }
    }

    private func watchSettings() {
        withObservationTracking {
            let settings = model.settings
            _ = settings.hotKey
            _ = settings.hotKeyEnabled
            _ = settings.hideDockIcon
            _ = settings.keepRunningInMenuBar
            _ = settings.keepPanelOnTop
            _ = settings.hasCompletedOnboarding
            _ = settings.accessMode
            _ = settings.menuBarStat
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applySettings()
                self?.watchSettings()
            }
        }
    }

    private func togglePanel() {
        // Locked: the shortcut leads to activation instead of an empty panel.
        guard model.license.isUnlocked else {
            NSApp.activate()
            LibraryWindowTracker.shared.showLibraryWindow()
            return
        }
        switch model.settings.accessMode {
        case .notch: notch?.toggle()
        case .menuBar: panel?.toggle(relativeTo: statusItem?.button)
        }
    }
}
