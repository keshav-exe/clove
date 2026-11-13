import AppKit
import SwiftUI

/// Lets AppKit code (status item, hot key, dock icon) reach the SwiftUI scenes.
/// The actions are registered once by the root view and stay valid after the
/// window is closed, which is how the app comes back from the menu bar.
@MainActor
final class WindowBridge {
    static let shared = WindowBridge()

    var panelWindow: NSWindow?

    var openLibraryWindow: (() -> Void)?
    var toggleQuickPanel: () -> Void = {}
    /// Set by the app delegate, which owns the global hotkey.
    var suspendHotKey: (Bool) -> Void = { _ in }

    private init() {}

    /// While a shortcut is being recorded, the current one mustn't fire.
    func setHotKeySuspended(_ suspended: Bool) {
        suspendHotKey(suspended)
    }

    func showLibraryWindow() {
        LibraryWindowTracker.shared.showLibraryWindow()
    }

    func showSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        // AppKit has no SettingsLink, so choose the app menu's own Settings item,
        // the one SwiftUI's Settings scene puts there.
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu,
              let index = appMenu.items.firstIndex(where: { $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command })
        else { return }
        appMenu.performActionForItem(at: index)
    }
}
