import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    lazy var updates = UpdateService(settings: model.settings)

    private var panel: PanelController?
    private var statusItem: StatusItemController?
    private let hotKeys = HotKeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = PanelController(model: model)
        self.panel = panel

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

        applySettings()
        watchSettings()
        InsertTarget.startObserving()
        updates.applyDeferredInstallIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(libraryWindowVisibilityChanged),
            name: .libraryWindowVisibilityDidChange,
            object: nil
        )

        // Status items can fail to appear if created before the run loop settles.
        DispatchQueue.main.async { [weak self] in
            self?.applyStatusItem()
        }

        NSApp.activate()

        #if DEBUG
        // `-panelPreview <block>`: open the panel pinned on a block, for screenshots.
        if let index = CommandLine.arguments.firstIndex(of: "-panelPreview") {
            let name = CommandLine.arguments.indices.contains(index + 1) ? CommandLine.arguments[index + 1] : ""
            if let block = PanelBlock(rawValue: name) {
                model.settings.setBlock(block, included: true)
                model.settings.panelBlock = block
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.panel?.setPinned(true)
                self?.panel?.show()
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
        LibraryWindowTracker.shared.keepRunningInMenuBar = model.settings.keepRunningInMenuBar
        applyActivationPolicy()
        applyStatusItem()
        applyHotKey()
        panel?.setPinned(model.settings.keepPanelOnTop)
    }

    private func applyActivationPolicy() {
        let settings = model.settings
        let wantsMenuBar = LibraryWindowTracker.shared.isLibraryVisible
            || hasVisibleRegularWindow

        let next: NSApplication.ActivationPolicy
        if !settings.hasCompletedOnboarding || !settings.showMenuBarIcon {
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

    private func applyStatusItem() {
        guard model.settings.showMenuBarIcon else {
            statusItem?.remove()
            statusItem = nil
            return
        }
        if statusItem == nil {
            let item = StatusItemController()
            item.onToggle = { [weak self] in
                self?.togglePanel()
            }
            item.onShow = { [weak self] destination in
                WindowBridge.shared.showLibraryWindow()
                self?.model.show(destination)
            }
            item.onSettings = {
                WindowBridge.shared.showSettings()
            }
            item.onCheckForUpdates = { [weak self] in
                guard let self else { return }
                WindowBridge.shared.showLibraryWindow()
                Task { await self.updates.checkForUpdates(userInitiated: true) }
            }
            item.panelShortcut = { [weak self] in
                guard let settings = self?.model.settings, settings.hotKeyEnabled else { return nil }
                return settings.hotKey
            }
            item.badge = { [weak self] destination in
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
            item.onQuit = {
                NSApp.terminate(nil)
            }
            statusItem = item
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
            _ = settings.showMenuBarIcon
            _ = settings.hideDockIcon
            _ = settings.keepRunningInMenuBar
            _ = settings.keepPanelOnTop
            _ = settings.hasCompletedOnboarding
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
        panel?.toggle(relativeTo: statusItem?.button)
    }
}
