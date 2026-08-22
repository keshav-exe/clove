import AppKit
import CoreGraphics

/// Copies a skill reference to the pasteboard and types it into the focused field
/// in whichever app the user was working in before Clove took focus.
@MainActor
enum SkillInserter {
    static func insert(_ text: String, resigningFrom window: NSWindow? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        window?.makeFirstResponder(nil)

        if let target = InsertTarget.application {
            target.activate(from: NSRunningApplication.current, options: [])
        }

        // Wait for the other app to become key before simulating ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard AccessibilityAccess.isGranted else { return }
            simulatePaste()
        }
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
