import AppKit

/// A clear, borderless canvas above the menu bar. It never draws anything of
/// its own; the island inside it does. Mouse events pass straight through
/// everywhere except the island, which the controller keeps up to date.
final class NotchWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: CGRect(origin: .zero, size: NotchGeometry.canvas),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // Above the menu bar, so the island can cover it.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        // The island draws its own shadow, only once it's open; a window shadow
        // would outline the whole canvas.
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        ignoresMouseEvents = true
        animationBehavior = .none
    }
}
