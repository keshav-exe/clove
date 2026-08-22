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

        let root = SkillsPanel()
            .environment(model)
            .environment(\.closePanel) { [weak self] in
                self?.hide()
            }
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
        if panel.isVisible {
            hide()
        } else {
            show(relativeTo: statusButton)
        }
    }

    func show(relativeTo statusButton: NSView? = nil) {
        InsertTarget.captureCurrent()
        model.prepareForDisplay()
        anchorStatusButton = statusButton
        position(relativeTo: statusButton)

        // `orderFrontRegardless` first: a status item click does not always grant
        // activation, and ordering front afterwards would lose the race.
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
        panel.orderOut(nil)
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
