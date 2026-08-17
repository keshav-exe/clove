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
        NSApp.activate()
        openLibraryWindow?()
    }

    func showSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
