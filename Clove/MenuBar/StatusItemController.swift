import AppKit

/// Menu bar mode's icon. A click toggles the panel; a right click or
/// Control-click opens the same menu the notch's right click does.
@MainActor
final class StatusItemController: NSObject {
    var onToggle: () -> Void = {}

    private let item: NSStatusItem
    private let menu: NSMenu

    var button: NSStatusBarButton? {
        item.button
    }

    init(menu: CloveMenu) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = menu.menu
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
        button.toolTip = "Clove: click for the panel, right-click for everything else"
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
}
