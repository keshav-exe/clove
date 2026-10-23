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

    private init() {}

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
