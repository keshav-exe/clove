import AppKit

/// The menu bar icon. A click toggles the quick access panel; a right click or
/// Control-click opens a menu with every part of Clove, the way the sidebar has them.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onToggle: () -> Void = {}
    var onShow: (SidebarItem) -> Void = { _ in }
    var onSettings: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}
    var onQuit: () -> Void = {}
    /// Read when the menu opens, so the shortcut shown is always the current one.
    var panelShortcut: () -> KeyChord? = { nil }
    /// Small counts beside a row, like the sidebar's badges.
    var badge: (SidebarItem) -> String? = { _ in nil }

    private let item: NSStatusItem
    private let menu = NSMenu()

    var button: NSStatusBarButton? {
        item.button
    }

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
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
            showMenu()
        } else {
            onToggle()
        }
    }

    private func configureButton() {
        guard let button else { return }
        let image = NSImage(resource: .menuBarIcon)
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "Clove: click for quick access, right-click for everything else"
        button.setAccessibilityLabel("Clove")
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// A live number beside the icon, in the menu bar's own font with steady
    /// digits so it doesn't jiggle as it changes. Nil goes back to the icon alone.
    func setStat(_ reading: (text: String, spoken: String)?) {
        guard let button else { return }
        if let reading, !reading.text.isEmpty {
            button.attributedTitle = NSAttributedString(
                string: " " + reading.text,
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
            )
            button.imagePosition = .imageLeading
            button.setAccessibilityLabel("Clove, \(reading.spoken)")
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel(reading.map { "Clove, \($0.spoken)" } ?? "Clove")
        }
    }

    private func showMenu() {
        // Attached only while it shows, so a left click stays free for the panel.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let panel = add("Quick Access Panel", symbol: "magnifyingglass", to: menu, action: #selector(togglePanel))
        // The global shortcut, drawn by AppKit on the right like any menu shortcut.
        if let chord = panelShortcut(), let key = chord.menuKeyEquivalent {
            panel.keyEquivalent = key
            panel.keyEquivalentModifierMask = chord.modifiers.cocoaFlags
        }

        menu.addItem(.separator())
        for (title, symbol, destination) in Self.places {
            show(title, symbol: symbol, destination: destination, in: menu)
        }

        menu.addItem(.separator())
        menu.addItem(submenu("Context", symbol: "text.document", kinds: ResourceKind.contextKinds))
        let tools = submenu("Tools & Access", symbol: "wrench.and.screwdriver", kinds: ResourceKind.toolKinds)
        tools.submenu?.addItem(.separator())
        if let submenu = tools.submenu {
            show("Secrets", symbol: "key", destination: .secrets, in: submenu)
        }
        menu.addItem(tools)

        menu.addItem(.separator())
        let settings = add("Settings…", symbol: "gearshape", to: menu, action: #selector(openSettings))
        settings.keyEquivalent = ","
        add("Check for Updates…", symbol: "arrow.down.circle", to: menu, action: #selector(checkForUpdates))
        menu.addItem(.separator())
        let quit = add("Quit Clove", symbol: nil, to: menu, action: #selector(quit))
        quit.keyEquivalent = "q"
    }

    private static let places: [(String, String, SidebarItem)] = [
        ("Home", "house", .home),
        ("Storage", "internaldrive", .storage),
        ("Cleanup", "leaf", .cleanup),
        ("Running", "waveform.path.ecg", .running),
        ("Skills", "square.stack.3d.up", .library(.all)),
        ("Discover", "safari", .discover),
    ]

    private func submenu(_ title: String, symbol: String, kinds: [ResourceKind]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for kind in kinds {
            show(kind.title, symbol: kind.symbolName, destination: .resources(kind), in: submenu)
        }
        parent.submenu = submenu
        return parent
    }

    private func show(_ title: String, symbol: String, destination: SidebarItem, in menu: NSMenu) {
        let entry = add(title, symbol: symbol, to: menu, action: #selector(showDestination(_:)))
        entry.representedObject = MenuDestination(destination)
        if let badge = badge(destination) {
            entry.badge = NSMenuItemBadge(string: badge)
        }
    }

    @discardableResult
    private func add(_ title: String, symbol: String?, to menu: NSMenu, action: Selector) -> NSMenuItem {
        let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        entry.target = self
        if let symbol {
            entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return entry
    }

    // MARK: - Actions

    @objc
    private func togglePanel() {
        onToggle()
    }

    @objc
    private func showDestination(_ sender: NSMenuItem) {
        guard let destination = sender.representedObject as? MenuDestination else { return }
        onShow(destination.item)
    }

    @objc
    private func openSettings() {
        onSettings()
    }

    @objc
    private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc
    private func quit() {
        onQuit()
    }
}

/// `representedObject` needs a class.
private final class MenuDestination: NSObject {
    let item: SidebarItem

    init(_ item: SidebarItem) {
        self.item = item
    }
}
