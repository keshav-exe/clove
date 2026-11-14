import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private let panel = FloatingPanel()
    private let model: AppModel
    private var isPinned = false
    private var hasCenteredOnce = false
    private var observers: [any NSObjectProtocol] = []
    private var outsideClickMonitor: Any?
    private var keyRouter: PanelKeyRouter?
    /// The status-item click that opens the panel can also hit the global
    /// outside-click monitor; ignore dismissals briefly after showing.
    private var suppressOutsideDismissUntil: Date?
    private weak var anchorStatusButton: NSView?

    init(model: AppModel) {
        self.model = model

        let root = QuickPanel()
            .environment(model)
            .environment(\.closePanel, ClosePanelAction { [weak self] in
                self?.hide()
            })
            .glassEffect(.regular, in: .rect(cornerRadius: Metrics.panelRadius))
            .clipShape(.rect(cornerRadius: Metrics.panelRadius))

        let hosting = NSHostingView(rootView: root)
        hosting.safeAreaRegions = []
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = Metrics.panelRadius
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: Metrics.panelWidth, height: Metrics.panelHeight))
        WindowBridge.shared.panelWindow = panel

        let router = PanelKeyRouter(model: model, panel: panel)
        router.onClose = { [weak self] in
            self?.hide()
        }
        router.start()
        keyRouter = router

        observeFrameChanges()
    }

    /// Pinned panels survive clicks in other apps, so they can sit next to an
    /// editor or terminal all day.
    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        panel.collectionBehavior = pinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary]
        if pinned {
            removeOutsideClickMonitor()
            restoreSavedFrame()
        } else if panel.isVisible {
            installOutsideClickMonitor()
        }
    }

    func toggle(relativeTo statusButton: NSView? = nil) {
        // Shown, not merely on screen: a click during the fade-out reopens it.
        if isShown {
            hide()
        } else {
            show(relativeTo: statusButton)
        }
    }

    func show(relativeTo statusButton: NSView? = nil) {
        InsertTarget.captureCurrent()
        model.prepareForDisplay()
        model.isPanelVisible = true
        anchorStatusButton = statusButton
        position(relativeTo: statusButton)

        // `orderFrontRegardless` first: a status item click does not always grant
        // activation, and ordering front afterwards would lose the race.
        animateIn(fromMenuBar: statusButton != nil)
        panel.orderFrontRegardless()

        if !isPinned {
            NSApp.activate()
            suppressOutsideDismissUntil = Date().addingTimeInterval(0.25)
            installOutsideClickMonitor()
        }

        panel.makeKey()
    }

    func hide() {
        saveFrameIfPinned()
        removeOutsideClickMonitor()
        animateOut()
    }

    // MARK: - Motion

    /// Bumped on every show and hide, so a hide that finishes after the panel
    /// was shown again doesn't take it away.
    private var presentation = 0
    /// The panel is shown or showing; false from the moment a hide starts.
    private var isShown = false

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// The way a popover arrives: it grows out of the menu bar, from its top
    /// edge, with a quick fade. Opened by the shortcut, it only fades, since
    /// there's no icon to grow from.
    private func animateIn(fromMenuBar: Bool) {
        presentation += 1
        isShown = true
        guard !reduceMotion, let layer = panel.contentView?.layer else {
            panel.alphaValue = 1
            return
        }
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        let bounds = layer.bounds
        let scale: CGFloat = fromMenuBar ? 0.96 : 0.98
        // Scale about the top centre: the layer's origin is bottom-left.
        let start = CATransform3DConcat(
            CATransform3DMakeScale(scale, scale, 1),
            CATransform3DMakeTranslation(bounds.width * (1 - scale) / 2, bounds.height * (1 - scale), 0)
        )
        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue = NSValue(caTransform3D: start)
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        spring.mass = 1
        spring.stiffness = 420
        spring.damping = 34
        spring.duration = spring.settlingDuration
        layer.transform = CATransform3DIdentity
        layer.add(spring, forKey: "present")
    }

    /// Out is quicker than in, and only a fade: it's getting out of the way.
    private func animateOut() {
        presentation += 1
        isShown = false
        let token = presentation
        guard !reduceMotion, panel.isVisible else {
            finishHiding()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.11
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.presentation == token else { return }
                self.finishHiding()
            }
        }
    }

    private func finishHiding() {
        panel.orderOut(nil)
        panel.alphaValue = 1
        model.isPanelVisible = false
    }

    /// Clicks inside Clove are delivered locally, so a global monitor only sees
    /// the "user moved on to another app" case we want to dismiss on.
    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let until = self.suppressOutsideDismissUntil, Date() < until {
                    return
                }
                // Clicks on the status item arrive as global events too.
                if self.isClickOnOwnStatusItem(event) {
                    return
                }
                self.hide()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func position(relativeTo statusButton: NSView?) {
        if isPinned, restoreSavedFrame() {
            return
        }

        if let statusButton, let window = statusButton.window {
            let buttonRect = statusButton.convert(statusButton.bounds, to: nil)
            let screenRect = window.convertToScreen(buttonRect)
            var origin = CGPoint(
                x: screenRect.midX - panel.frame.width / 2,
                y: screenRect.minY - panel.frame.height - 8
            )
            origin = clampToScreen(origin, size: panel.frame.size, screen: window.screen)
            panel.setFrameOrigin(origin)
            return
        }

        guard !hasCenteredOnce else { return }
        panel.center()
        hasCenteredOnce = true
    }

    @discardableResult
    private func restoreSavedFrame() -> Bool {
        guard let raw = model.settings.pinnedPanelFrame else { return false }
        let frame = NSRectFromString(raw)
        guard frame.width > 0, frame.height > 0 else { return false }
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) else { return false }
        panel.setFrame(frame, display: false)
        return true
    }

    private func saveFrameIfPinned() {
        guard isPinned, panel.isVisible else { return }
        model.settings.pinnedPanelFrame = NSStringFromRect(panel.frame)
    }

    private func observeFrameChanges() {
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didEndLiveResizeNotification] {
            let token = center.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.saveFrameIfPinned()
                }
            }
            observers.append(token)
        }
    }

    private func isClickOnOwnStatusItem(_ event: NSEvent) -> Bool {
        guard event.window == nil, let button = anchorStatusButton, let window = button.window else {
            return false
        }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        return frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation)
    }

    private func clampToScreen(_ origin: CGPoint, size: CGSize, screen: NSScreen?) -> CGPoint {
        guard let visible = screen?.visibleFrame else { return origin }
        var point = origin
        point.x = min(max(point.x, visible.minX + 8), visible.maxX - size.width - 8)
        point.y = min(max(point.y, visible.minY + 8), visible.maxY - size.height - 8)
        return point
    }
}
