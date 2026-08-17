@preconcurrency import ApplicationServices
import AppKit

enum AccessibilityAccess {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system dialog that offers to open Privacy settings.
    static func requestPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
