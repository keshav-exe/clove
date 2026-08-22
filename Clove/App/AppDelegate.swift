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

        applySettings()
        watchSettings()
        InsertTarget.startObserving()
        updates.applyDeferredInstallIfNeeded()

        // Status items can fail to appear if created before the run loop settles.
        DispatchQueue.main.async { [weak self] in
            self?.applyStatusItem()
        }

        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowBridge.shared.showLibraryWindow()
        }
        return true
    }

    // MARK: - Settings

    private func applySettings() {
        applyActivationPolicy()
        applyStatusItem()
        applyHotKey()
        panel?.setPinned(model.settings.keepPanelOnTop)
    }

    private func applyActivationPolicy() {
        let settings = model.settings
        let accessory = settings.hasCompletedOnboarding && settings.hideDockIcon && settings.showMenuBarIcon
        NSApp.setActivationPolicy(accessory ? .accessory : .regular)
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
            item.onOpenWindow = {
                WindowBridge.shared.showLibraryWindow()
            }
            item.onSettings = {
                WindowBridge.shared.showSettings()
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
        guard LicenseService.shared.isUnlocked else {
            WindowBridge.shared.showLibraryWindow()
            return
        }
        panel?.toggle(relativeTo: statusItem?.button)
    }
}
