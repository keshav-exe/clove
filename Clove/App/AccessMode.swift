import AppKit

/// Where Clove lives on screen. Both open the same tabs; they differ in how
/// you reach them and whether Clove can show what's live without being asked.
enum AccessMode: String, CaseIterable, Identifiable, Sendable {
    /// An island over the notch: hover to peek, click or the shortcut to
    /// search, and moments when agents finish or servers change.
    case notch
    /// An icon in the menu bar with a panel under it, for Macs that already
    /// give the notch to another app, or anyone who'd rather keep it clear.
    case menuBar

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .notch: NotchGeometry.hasHardwareNotch ? "Notch" : "Top of the Screen"
        case .menuBar: "Menu Bar"
        }
    }
}

extension NotchGeometry {
    /// Whether the Mac's built-in display has a notch, for how Clove talks about it.
    @MainActor
    static var hasHardwareNotch: Bool {
        NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
    }
}
