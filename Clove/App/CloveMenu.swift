import AppKit

/// Every part of Clove in one menu, the way the sidebar has them. Opened by
/// a right click on the notch, or on the menu bar icon.
@MainActor
final class CloveMenu: NSObject, NSMenuDelegate {
    var onOpenPanel: () -> Void = {}
    var onShow: (SidebarItem) -> Void = { _ in }
    var onSettings: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}
    var onQuit: () -> Void = {}
    /// Read when the menu opens, so the shortcut shown is always the current one.
    var panelShortcut: () -> KeyChord? = { nil }
    /// Small counts beside a row, like the sidebar's badges.
    var badge: (SidebarItem) -> String? = { _ in nil }

    /// Built fresh each time it opens. The status item attaches it directly.
    let menu = NSMenu()

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    /// Pops up at a point on screen, in global coordinates.
    func popUp(at location: CGPoint) {
        menu.popUp(positioning: nil, at: location, in: nil)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let panel = add("Open Panel", symbol: "magnifyingglass", to: menu, action: #selector(openPanel))
        // The global shortcut, drawn by AppKit on the right like any menu shortcut.
        if let chord = panelShortcut(), let key = chord.menuKeyEquivalent {
            panel.keyEquivalent = key
            panel.keyEquivalentModifierMask = chord.modifiers.cocoaFlags
        }

        for group in Self.places {
            menu.addItem(.separator())
            for (title, symbol, destination) in group {
                show(title, symbol: symbol, destination: destination, in: menu)
            }
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

    /// Grouped as the sidebar is: home, this Mac, then skills.
    private static let places: [[(String, String, SidebarItem)]] = [
        [("Home", "house", .home)],
        [
            ("Activity", "waveform.path.ecg", .running),
            ("Storage", "internaldrive", .storage),
        ],
        [
            ("Skills", "square.stack.3d.up", .library(.all)),
            ("Discover", "safari", .discover),
            ("Cleanup", "leaf", .cleanup),
        ],
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
    private func openPanel() {
        onOpenPanel()
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
