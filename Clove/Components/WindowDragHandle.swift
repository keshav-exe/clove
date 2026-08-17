import AppKit
import SwiftUI

/// Drag here to reposition the panel. Skill rows keep their own drag for inserting.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView()
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

final class DragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

struct WindowDragGrip: View {
    var body: some View {
        WindowDragHandle()
            .frame(width: 14, height: 38)
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .accessibilityLabel("Move panel")
            .help("Drag to move the panel")
    }
}
