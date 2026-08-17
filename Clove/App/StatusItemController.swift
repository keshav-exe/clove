import AppKit

@MainActor
final class StatusItemController: NSObject {
    var onToggle: () -> Void = {}
    var onOpenWindow: () -> Void = {}
    var onSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    private let item: NSStatusItem

    var button: NSStatusBarButton? {
        item.button
    }

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    @objc
    func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onToggle()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu(from: sender)
        } else {
            onToggle()
        }
    }

    private func configureButton() {
        guard let button else { return }
        let image = NSImage(resource: .menuBarIcon)
        image.isTemplate = true
        image.size = NSSize(width: 19, height: 18)
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "Clove"
        button.setAccessibilityLabel("Clove")
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quick Access Panel", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Skill Library…", action: #selector(openWindow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clove", action: #selector(quit), keyEquivalent: "q"))
        for entry in menu.items {
            entry.target = self
        }
        item.menu = menu
        button.performClick(nil)
        item.menu = nil
    }

    @objc
    private func togglePanel() {
        onToggle()
    }

    @objc
    private func openWindow() {
        onOpenWindow()
    }

    @objc
    private func openSettings() {
        onSettings()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
