import AppKit

/// Where the island lives on a screen, and how big its resting shape is.
///
/// On a screen with a notch (or any camera cutout macOS reports as one), the
/// island hangs from the top edge in the hardware's black. On a screen
/// without one, an external display or a Mac with no notch, it's a Dynamic
/// Island: a black pill floating in the menu bar, there only while something
/// is live, growing into the same panels as the notch.
struct NotchGeometry: Equatable {
    enum Style: Equatable {
        /// Hangs from the top edge, around the camera.
        case notch
        /// Floats in the menu bar, rounded all round.
        case island
    }

    /// The screen's full frame, in global coordinates.
    let screenFrame: CGRect
    /// The resting shape: the notch's own size, or the pill's.
    let size: CGSize
    /// Horizontal centre of the island, in global coordinates.
    let midX: CGFloat
    let style: Style
    /// The gap between the top of the screen and the island: none for a notch,
    /// a little for the floating pill so it sits inside the menu bar.
    let topInset: CGFloat

    /// A real notch, so the island is drawn flush with the hardware.
    var isHardware: Bool { style == .notch }

    /// Which display the island goes on.
    enum Placement: String, CaseIterable, Identifiable, Sendable {
        /// The Mac's own screen: its notch, if it has one.
        case builtIn
        /// Whichever display holds the window you're working in.
        case active

        var id: String { rawValue }

        var title: String {
            switch self {
            case .builtIn: "Built-in display"
            case .active: "The display you're using"
            }
        }
    }

    @MainActor
    static func current(placement: Placement = .builtIn) -> NotchGeometry? {
        let screens = NSScreen.screens
        if placement == .active, let screen = NSScreen.main, let geometry = NotchGeometry(screen) {
            return geometry
        }
        if let notched = screens.first(where: { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }), let geometry = NotchGeometry(notched) {
            return geometry
        }
        let builtIn = screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDisplayIsBuiltin($0.uint32Value) != 0 } ?? false
        }
        return (builtIn ?? screens.first).flatMap(NotchGeometry.init)
    }

    /// The floating pill: a little narrower than a notch, and a few points
    /// shorter than the menu bar so it reads as an island inside it.
    static let pillWidth: CGFloat = 128

    @MainActor
    init?(_ screen: NSScreen) {
        let frame = screen.frame
        screenFrame = frame
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            // The camera housing is the space between the two menu bar areas
            // macOS leaves either side of it.
            let width = frame.width - left.width - right.width
            size = CGSize(width: width, height: top)
            midX = frame.minX + left.width + width / 2
            style = .notch
            topInset = 0
        } else {
            let menuBar = max(frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            let bar = min(max(menuBar, 22), 40)
            let height = max(bar - 4, 20)
            size = CGSize(width: Self.pillWidth, height: height)
            midX = frame.midX
            style = .island
            topInset = ((bar - height) / 2).rounded()
        }
        guard size.width > 0, size.height > 0 else { return nil }
    }

    init(screenFrame: CGRect, size: CGSize, midX: CGFloat, style: Style, topInset: CGFloat = 0) {
        self.screenFrame = screenFrame
        self.size = size
        self.midX = midX
        self.style = style
        self.topInset = topInset
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

    /// A rect of `size` at the island's top, centred on it: hanging from the
    /// screen's edge for a notch, a few points below it for the pill.
    func hangingRect(_ size: CGSize) -> CGRect {
        CGRect(x: midX - size.width / 2, y: screenFrame.maxY - topInset - size.height, width: size.width, height: size.height)
    }
}
