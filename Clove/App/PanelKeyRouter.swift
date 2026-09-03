import AppKit

/// Keyboard handling for the quick access panel.
///
/// The panel always keeps a text field focused so you can type straight away,
/// and a focused text field swallows arrows, Return and Escape before SwiftUI
/// ever sees them. A local key monitor runs ahead of the field editor, handles
/// the panel's own shortcuts, and passes everything else through to typing.
@MainActor
final class PanelKeyRouter {
    var onClose: () -> Void = {}

    private let model: AppModel
    private weak var panel: NSWindow?
    private var monitor: Any?

    init(model: AppModel, panel: NSWindow) {
        self.model = model
        self.panel = panel
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { self.handle(event) }
            return handled ? nil : event
        }
    }

    /// Returns `true` when the panel consumed the key, so the field editor
    /// never sees it.
    private func handle(_ event: NSEvent) -> Bool {
        guard let panel else { return false }
        // SwiftUI field editors sometimes report a nil window. Accept the event
        // when the panel is key, or when the event is clearly from this panel.
        if let window = event.window, window !== panel { return false }
        if event.window == nil, !panel.isKeyWindow { return false }

        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let control = flags.contains(.control)
        let option = flags.contains(.option)

        if let code = KeyCode(rawValue: event.keyCode) {
            switch code {
            case .downArrow:
                model.selectNext(extending: shift)
                return true
            case .upArrow:
                model.selectPrevious(extending: shift)
                return true
            case .home:
                model.selectFirst()
                return true
            case .end:
                model.selectLast()
                return true
            case .escape:
                handleEscape()
                return true
            case .tab:
                if !model.pinnedGroups.isEmpty {
                    model.cyclePinnedGroup()
                }
                return true
            case .returnKey, .enter:
                return handleReturn(command: command, option: option)
            }
        }

        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        if control, !command {
            switch key {
            case "n":
                model.selectNext(extending: shift)
                return true
            case "p":
                model.selectPrevious(extending: shift)
                return true
            default:
                break
            }
        }

        guard command else { return false }

        switch key {
        case "a" where shift:
            model.selectAllVisible()
            return true
        case "c" where shift:
            model.copySelectedSkillGroup()
            return true
        case "f":
            model.requestFocus(.search)
            return true
        case "r":
            Task { await model.refresh() }
            return true
        case "l":
            onClose()
            WindowBridge.shared.showLibraryWindow()
            return true
        case ",":
            onClose()
            WindowBridge.shared.showSettings()
            return true
        case "w":
            onClose()
            return true
        default:
            return false
        }
    }

    /// Return types the highlighted skill into the app you came from.
    /// Option keeps the panel up and only copies, so you can grab another.
    private func handleReturn(command: Bool, option: Bool) -> Bool {
        model.confirmPanelSelection(option: option, command: command, dismiss: onClose)
        return true
    }

    private func handleEscape() {
        if !model.query.isEmpty {
            model.clearQuery()
        } else if model.activeTag != nil {
            model.clearTagFilter()
        } else {
            onClose()
        }
    }

    private enum KeyCode: UInt16 {
        case returnKey = 36
        case tab = 48
        case escape = 53
        case enter = 76
        case home = 115
        case end = 119
        case downArrow = 125
        case upArrow = 126
    }
}
