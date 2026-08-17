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
        guard let panel, event.window === panel else { return false }

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
                model.requestFocus(model.activeFocus == .search ? .footer : .search)
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

    /// Return copies and gets out of the way. Option keeps the panel up so you
    /// can grab a second skill, Command types the reference into the app you
    /// came from.
    private func handleReturn(command: Bool, option: Bool) -> Bool {
        if model.activeFocus == .footer, !command, !option {
            return false
        }

        guard !model.selectedSkills.isEmpty else { return true }

        if command {
            model.insertSelected()
            onClose()
            return true
        }

        model.copySelectedReferences()
        if !option {
            onClose()
        }
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
