import AppKit
import SwiftUI

/// Runs the island: puts its window over the notch, decides when it opens and
/// closes, and lets every click outside it fall through to the menu bar.
///
/// One island, opened two ways:
/// - Hover the notch: it opens without taking focus, and closes again as
///   soon as the pointer leaves. Passing by never steals your typing.
/// - Click it, or press the shortcut: it opens focused, and stays until you
///   press Esc, click the notch or anywhere else, or press the shortcut again.
///   Clicking into a hovered island focuses it the same way.
@MainActor
final class NotchController {
    let notch: NotchModel
    /// Called instead of opening while Clove is locked, to show activation.
    var onLocked: () -> Void = {}
    private let menu: CloveMenu

    private let model: AppModel
    private let window = NotchWindow()
    private var keyRouter: PanelKeyRouter?
    private var monitors: [Any] = []
    private var screenObserver: (any NSObjectProtocol)?
    private var activeObservers: [any NSObjectProtocol] = []
    private var activeTimer: Timer?

    private var hoverTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var unloadTask: Task<Void, Never>?


    private var isPinned = false
    private var isVisible = false
    /// Another app's island (Shotput's) has the notch right now.
    private var isYielding = false
    private var yieldTask: Task<Void, Never>?
    private var handshakeObservers: [any NSObjectProtocol] = []

    init(model: AppModel, notch: NotchModel, menu: CloveMenu) {
        self.model = model
        self.notch = notch
        self.menu = menu

        let actions = NotchActions(
            open: { [weak self] block in self?.open(block) },
            close: { [weak self] in self?.close() },
            showMenu: { [weak self] in self?.showMenu() }
        )
        let root = NotchView()
            .environment(model)
            .environment(notch)
            .environment(\.notchActions, actions)
            .environment(\.closePanel, ClosePanelAction { [weak self] in self?.close() })

        let hosting = NotchHostingView(rootView: root)
        hosting.safeAreaRegions = []
        hosting.onRightClick = { [weak self] in self?.showMenu() }
        window.contentView = hosting

        let router = PanelKeyRouter(model: model, panel: window)
        router.onClose = { [weak self] in self?.close() }
        router.start()
        keyRouter = router

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        installMouseMonitors()
        followActiveDisplay()
        listenForPartners()
        observeOpenState()
    }

    // MARK: - Sharing the notch

    private func listenForPartners() {
        let center = DistributedNotificationCenter.default()
        handshakeObservers = [
            center.addObserver(forName: NotchHandshake.shotputDidClaim, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.yield(true) }
            },
            center.addObserver(forName: NotchHandshake.shotputDidRelease, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.yield(false) }
            },
        ]
    }

    /// Folds back to the bare notch while a partner has claimed it: no ears,
    /// no hover, and moments wait in line. Releasing brings them back.
    private func yield(_ yielding: Bool) {
        yieldTask?.cancel()
        guard yielding != isYielding else {
            // A repeated claim restarts the safety timer.
            if yielding { startYieldTimeout() }
            return
        }
        isYielding = yielding
        if yielding {
            close()
            notch.clearMoments()
            notch.isYielding = true
            if notch.phase != .collapsed { notch.phase = .collapsed }
            window.ignoresMouseEvents = true
            startYieldTimeout()
        } else {
            notch.isYielding = false
            notch.resumeMoments()
            updatePointer(NSEvent.mouseLocation)
        }
    }

    private func startYieldTimeout() {
        yieldTask = Task { [weak self] in
            try? await Task.sleep(for: NotchHandshake.yieldTimeout)
            guard !Task.isCancelled else { return }
            self?.yield(false)
        }
    }

    /// Tells partners when Clove's island opens and closes.
    private func observeOpenState() {
        withObservationTracking {
            _ = notch.phase
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                NotchHandshake.post(self.notch.isExpanded ? NotchHandshake.cloveDidOpen : NotchHandshake.cloveDidClose)
                self.observeOpenState()
            }
        }
    }

    // MARK: - Showing

    /// Hidden until onboarding is done, so the notch doesn't announce an app
    /// you haven't met yet.
    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible {
            WindowBridge.shared.panelWindow = window
            reposition()
            window.orderFrontRegardless()
        } else {
            close()
            window.orderOut(nil)
        }
    }

    /// Pinned, the panel survives clicks elsewhere, so it can sit beside an
    /// editor while you work.
    func setPinned(_ pinned: Bool) {
        isPinned = pinned
    }

    private func reposition() {
        guard let geometry = NotchGeometry.current(placement: model.settings.islandPlacement) else { return }
        guard geometry != notch.geometry else { return }
        notch.geometry = geometry
        window.setFrame(geometry.windowFrame, display: true)
        window.appearance = NSAppearance(named: .darkAqua)
    }

    /// With the island on the display you're using, it moves when you switch
    /// apps or windows to another one. Only while it's closed: an open island
    /// never jumps out from under the pointer.
    private func followActiveDisplay() {
        let workspace = NSWorkspace.shared.notificationCenter
        activeObservers = [
            workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.moveToActiveDisplay() }
            },
            NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.moveToActiveDisplay() }
            },
        ]
        // Other apps' windows moving between displays don't notify; look now and then.
        activeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.moveToActiveDisplay() }
        }
    }

    private func moveToActiveDisplay() {
        guard isVisible, model.settings.islandPlacement == .active,
              notch.phase == .collapsed, notch.moment == nil else { return }
        reposition()
    }

    func toggle() {
        if notch.phase == .open, notch.isFocused {
            close()
        } else {
            open(nil, focused: true)
        }
    }

    /// Opens on a tab (nil keeps the last one), focused or just to look.
    func open(_ block: PanelBlock? = nil, focused: Bool = true) {
        guard isVisible, !isYielding else { return }
        guard model.license.isUnlocked else {
            close()
            onLocked()
            return
        }
        cancelTimers()
        if let block, model.settings.panelBlocks.contains(block) {
            model.settings.panelBlock = block
        }
        if notch.phase != .open {
            InsertTarget.captureCurrent()
            model.prepareForDisplay()
            Task { await model.running.refresh(known: model.knownServers) }
        }
        notch.clearMoments()
        model.isPanelVisible = true
        notch.phase = .open
        window.ignoresMouseEvents = false
        if focused { focus() }
    }

    /// Takes the keyboard, so search and arrows work. The island is a
    /// non-activating panel, so it gets keys without activating Clove: the app
    /// you were in stays frontmost, and Clove's own window can't steal focus.
    private func focus() {
        notch.isFocused = true
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        cancelTimers()
        let wasFocused = notch.isFocused
        let wasOpen = notch.phase == .open
        notch.isFocused = false
        if notch.phase != .collapsed {
            notch.phase = .collapsed
        }
        updatePointer(NSEvent.mouseLocation)
        if wasFocused, window.isKeyWindow {
            window.resignKey()
        }
        guard wasOpen else { return }
        // The tabs unload once the island has closed over them.
        unloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled, self.notch.phase != .open else { return }
            self.model.isPanelVisible = false
        }
    }

    private func cancelTimers() {
        hoverTask?.cancel()
        collapseTask?.cancel()
        unloadTask?.cancel()
    }

    private func showMenu() {
        menu.popUp(at: NSEvent.mouseLocation)
    }

    // MARK: - Pointer

    private var islandRect: CGRect {
        notch.geometry?.hangingRect(notch.size) ?? .zero
    }

    /// The hardware notch itself, in the middle of the island's top strip.
    private var notchRect: CGRect {
        notch.geometry?.hangingRect(notch.notchSize) ?? .zero
    }

    /// The notch plus a sliver below it: reaching for the notch shouldn't need
    /// pixel-perfect aim, but passing beside it shouldn't open anything.
    private var hoverRect: CGRect {
        guard let geometry = notch.geometry else { return .zero }
        let size = CGSize(width: notch.size.width, height: notch.notchSize.height + 4)
        return geometry.hangingRect(size)
    }

    private func installMouseMonitors() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, isLocal: false) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, isLocal: true) }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handle(_ event: NSEvent, isLocal: Bool) {
        guard isVisible, !isYielding else { return }
        let location = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            guard notch.phase == .open else { break }
            let inIsland = isLocal && event.window === window
            if inIsland {
                // A click in a hovered island takes focus, so typing goes
                // there; once focused, clicking the notch itself closes it.
                if notch.isFocused, notchRect.contains(location) {
                    close()
                } else {
                    focus()
                }
            } else if !isPinned || !notch.isFocused {
                // Anywhere else: another app, the menu bar, Clove's own window.
                close()
            }
        default:
            break
        }
        updatePointer(location)
    }

    /// Keeps clicks falling through everywhere but the island, and opens or
    /// closes a hovered island as the pointer comes and goes.
    private func updatePointer(_ location: CGPoint) {
        let island = islandRect
        let overIsland = island.insetBy(dx: -2, dy: -2).contains(location)
        let overNotch = hoverRect.contains(location)
        window.ignoresMouseEvents = !(overIsland || overNotch)

        switch notch.phase {
        case .collapsed:
            let buttons = NSEvent.pressedMouseButtons
            if overNotch, buttons == 0, !isYielding, model.settings.notchOpensOnHover {
                guard hoverTask == nil else { return }
                hoverTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(140))
                    guard let self, !Task.isCancelled else { return }
                    self.hoverTask = nil
                    if self.hoverRect.contains(NSEvent.mouseLocation), self.notch.phase == .collapsed {
                        self.open(nil, focused: false)
                    }
                }
            } else {
                hoverTask?.cancel()
                hoverTask = nil
            }
        case .open where !notch.isFocused:
            // A little slack around the edge, so a pointer that drifts off for
            // a moment doesn't snap it shut.
            if island.insetBy(dx: -14, dy: -14).contains(location) {
                collapseTask?.cancel()
                collapseTask = nil
            } else if collapseTask == nil {
                collapseTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(200))
                    guard let self, !Task.isCancelled else { return }
                    self.collapseTask = nil
                    if self.notch.phase == .open, !self.notch.isFocused { self.close() }
                }
            }
        case .open, .moment:
            break
        }
    }
}

/// Hosts the island and shows the menu on a right click anywhere on it.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: () -> Void = {}

    /// A view with its own context menu (a port, a widget, a section) gets
    /// that menu; anywhere else, Clove's menu.
    override func rightMouseDown(with event: NSEvent) {
        if menu(for: event) != nil {
            super.rightMouseDown(with: event)
        } else {
            onRightClick()
        }
    }

    /// The island takes the first click even while another app is active, so
    /// a click on the notch opens it instead of only activating Clove.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
