import AppKit
import ApplicationServices
import CoreGraphics

/// Copies a skill reference to the pasteboard and types it into the focused field
/// in whichever app the user was working in before Clove took focus.
@MainActor
enum SkillInserter {
    private static var lastInsertion: (text: String, at: Date)?

    static func insert(_ text: String, resigningFrom window: NSWindow? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let now = Date()
        if let last = lastInsertion, last.text == text, now.timeIntervalSince(last.at) < 0.4 {
            return
        }
        lastInsertion = (text, now)

        window?.makeFirstResponder(nil)

        guard let target = InsertTarget.application else { return }

        NSApp.yieldActivation(to: target)
        _ = target.activate(from: NSRunningApplication.current)

        pasteWhenReady(text, target: target)
    }

    private static func pasteWhenReady(_ text: String, target: NSRunningApplication, attempt: Int = 0) {
        if target.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
            insertIntoFocusedField(text)
            return
        }

        guard attempt < 12 else {
            insertIntoFocusedField(text)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            pasteWhenReady(text, target: target, attempt: attempt + 1)
        }
    }

    private static func insertIntoFocusedField(_ text: String) {
        guard AccessibilityAccess.isGranted else { return }
        if insertViaAccessibility(text) { return }
        simulatePaste()
    }

    /// Electron apps (Cursor, VS Code) often ignore synthetic ⌘V. Setting the
    /// focused element's selected text inserts at the caret instead.
    private static func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else {
            return false
        }

        let focused = focusedRef as! AXUIElement
        return AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        ) == .success
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
