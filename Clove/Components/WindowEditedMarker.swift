import AppKit
import SwiftUI

/// Shows the dot in the window's close button while there are unsaved changes.
struct WindowEditedMarker: NSViewRepresentable {
    let isEdited: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.window?.isDocumentEdited = isEdited
    }
}
