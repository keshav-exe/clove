import AppKit

/// Where the notch is, and how big. Screens without one get a stand-in the
/// size of a small notch, drawn at the top centre of the menu bar.
struct NotchGeometry: Equatable {
    /// The screen's full frame, in global coordinates.
    let screenFrame: CGRect
    /// The notch's width and height. Height is the menu bar's on screens without one.
    let size: CGSize
    /// Horizontal centre of the notch, in global coordinates.
    let midX: CGFloat
    /// A real notch, so the island is drawn in the hardware's black. Screens
    /// without one get glass instead: there is nothing to blend into.
    let isHardware: Bool

    /// The screen that holds the notch, else the one with the menu bar.
    @MainActor
    static func current() -> NotchGeometry? {
        let screens = NSScreen.screens
        if let notched = screens.first(where: { $0.safeAreaInsets.top > 0 }), let geometry = NotchGeometry(notched) {
            return geometry
        }
        return screens.first.flatMap(NotchGeometry.init)
    }

    @MainActor
    init?(_ screen: NSScreen) {
        let frame = screen.frame
        screenFrame = frame
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = frame.width - left.width - right.width
            size = CGSize(width: width, height: top)
            midX = frame.minX + left.width + width / 2
            isHardware = true
        } else {
            let menuBar = max(frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            // Only the menu bar sits above visibleFrame unless the Dock is at the top, which it can't be.
            size = CGSize(width: 180, height: min(menuBar, 32))
            midX = frame.midX
            isHardware = false
        }
        guard size.width > 0, size.height > 0 else { return nil }
    }

    /// The window is a fixed canvas the island grows inside, so it never has to
    /// resize mid-animation. Wide and tall enough for the biggest state.
    static let canvas = CGSize(width: 760, height: 600)

    var windowFrame: CGRect {
        CGRect(
            x: (midX - Self.canvas.width / 2).rounded(),
            y: screenFrame.maxY - Self.canvas.height,
            width: Self.canvas.width,
            height: Self.canvas.height
        )
    }

    /// A rect of `size`, hanging from the top edge of the screen, centred on the notch.
    func hangingRect(_ size: CGSize) -> CGRect {
        CGRect(x: midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }
}
