import AppKit
import SwiftUI

extension Notification.Name {
    static let libraryWindowVisibilityDidChange = Notification.Name("libraryWindowVisibilityDidChange")
}

/// Keeps the library window alive in the background and hides it instead of closing.
@MainActor
final class LibraryWindowTracker: NSObject, NSWindowDelegate {
    static let shared = LibraryWindowTracker()

    private(set) var isLibraryVisible = true
    private weak var window: NSWindow?
    private var openWindow: (() -> Void)?
    var keepRunningInMenuBar = true

    private override init() {
        super.init()
    }

    func registerOpenWindow(_ action: @escaping () -> Void) {
        openWindow = action
    }

    func bind(window: NSWindow) {
        guard window !== self.window else { return }
        self.window = window
        window.delegate = self
        window.isReleasedWhenClosed = !keepRunningInMenuBar
        isLibraryVisible = window.isVisible
    }

    func showLibraryWindow() {
        NSApp.activate()
        if let window {
            window.makeKeyAndOrderFront(nil)
            setVisible(true)
            return
        }
        openWindow?()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard keepRunningInMenuBar else { return true }
        sender.orderOut(nil)
        setVisible(false)
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) {
        setVisible(true)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        setVisible(false)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        setVisible(true)
    }

    private func setVisible(_ visible: Bool) {
        guard isLibraryVisible != visible else { return }
        isLibraryVisible = visible
        NotificationCenter.default.post(name: .libraryWindowVisibilityDidChange, object: nil)
    }
}

struct LibraryWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                LibraryWindowTracker.shared.bind(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                LibraryWindowTracker.shared.bind(window: window)
            }
        }
    }
}
