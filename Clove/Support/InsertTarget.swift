import AppKit

/// Remembers which app should receive pasted skill references.
@MainActor
enum InsertTarget {
    private(set) static var application: NSRunningApplication?
    private static var observer: (any NSObjectProtocol)?

    static func startObserving() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                remember(app)
            }
        }
    }

    /// Call right before Clove takes focus, so insert goes back to the app you were in.
    static func captureCurrent() {
        remember(NSWorkspace.shared.frontmostApplication)
    }

    private static func remember(_ app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        application = app
    }
}
