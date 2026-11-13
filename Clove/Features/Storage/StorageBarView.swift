import AppKit
import Observation
import QuartzCore
import SwiftUI

/// The numbers that count along with the bar. Written only when the text
/// changes, so the card re-renders at the rate digits flip, not the frame rate.
@MainActor
@Observable
final class StorageReadout {
    var used = ""
    var sizes = [String](repeating: "", count: StorageKind.allCases.count)
}

/// Draws the bar on a display link, in the space the card leaves for it plus
/// a margin for the glow and the motes.
struct StorageBarView: NSViewRepresentable {
    let store: StorageStore
    let readout: StorageReadout
    /// The kind being looked at, or -1.
    let hover: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> StorageBarNSView {
        let view = StorageBarNSView(store: store, readout: readout)
        view.hover = hover
        view.reduceMotion = reduceMotion
        return view
    }

    func updateNSView(_ view: StorageBarNSView, context: Context) {
        view.hover = hover
        view.reduceMotion = reduceMotion
        view.wake()
    }

    static func dismantleNSView(_ view: StorageBarNSView, coordinator: ()) {
        view.stop()
    }
}

/// A heavy spring, stepped at 240Hz however the frames fall.
private struct Spring {
    var x: Double
    var v: Double = 0

    @discardableResult
    mutating func step(to target: Double, k: Double, c: Double, dt: Double, snap: Bool = false) -> Bool {
        if snap {
            x = target
            v = 0
            return false
        }
        let steps = max(1, Int((dt / (1.0 / 240)).rounded(.up)))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            v += (k * (target - x) - c * v) * h
            x += v * h
        }
        if abs(v) < 0.4, abs(target - x) < 0.02 {
            x = target
            v = 0
            return false
        }
        return true
    }
}

final class StorageBarNSView: NSView {
    var hover = -1
    var reduceMotion = false

    private let store: StorageStore
    private let readout: StorageReadout
    private var renderer: StorageBarRenderer?

    // The GPU stacks what the renderer draws: glow under the bar, the bar's
    // tints and cells clipped to its rounded track, filaments and motes on top.
    private let glowLayer = CALayer()
    private let trackLayer = CALayer()
    private var fillLayers: [CALayer] = []
    private let cellsLayer = CALayer()
    private let overlayLayer = CALayer()
    private var occlusion: NSObjectProtocol?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var clock: Double = 0
    private var started = false
    private var settledFrames = 0

    private var sizes: [Spring]
    private var focus: [Spring]
    private var dim = Spring(x: 0)
    private var scanGlow = Spring(x: 0)
    private var scanStart: CFTimeInterval?

    init(store: StorageStore, readout: StorageReadout) {
        self.store = store
        self.readout = readout
        sizes = StorageKind.allCases.map { _ in Spring(x: 0) }
        focus = StorageKind.allCases.map { _ in Spring(x: 0) }
        super.init(frame: .zero)
        wantsLayer = true
        setUpLayers()
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func setUpLayers() {
        guard let root = layer else { return }
        // Scaled up from a pixel per cell, smoothly, then blended at 70% like the sandbox's blurred canvas.
        glowLayer.magnificationFilter = .linear
        glowLayer.opacity = 0.7
        trackLayer.cornerRadius = StorageBarRenderer.radius
        trackLayer.cornerCurve = .circular
        trackLayer.masksToBounds = true
        trackLayer.borderWidth = 1
        trackLayer.borderColor = CGColor(gray: 1, alpha: 0.07)
        cellsLayer.magnificationFilter = .nearest
        cellsLayer.contentsGravity = .resize
        overlayLayer.contentsGravity = .resize
        fillLayers = StorageKind.allCases.map { _ in CALayer() }
        for fill in fillLayers { trackLayer.addSublayer(fill) }
        trackLayer.addSublayer(cellsLayer)
        root.addSublayer(glowLayer)
        root.addSublayer(trackLayer)
        root.addSublayer(overlayLayer)
        for sublayer in [glowLayer, trackLayer, cellsLayer, overlayLayer] + fillLayers {
            sublayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull(), "frame": NSNull()]
        }
    }

    /// Canvas rects are top-left; this view's layers are bottom-left.
    private func flip(_ rect: CGRect, in height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    private func layOutLayers() {
        guard let renderer else { return }
        let height = renderer.canvas.height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = flip(renderer.glowRect, in: height)
        trackLayer.frame = flip(renderer.barRect, in: height)
        cellsLayer.frame = trackLayer.bounds
        cellsLayer.contentsScale = renderer.scale
        overlayLayer.frame = CGRect(origin: .zero, size: renderer.canvas)
        overlayLayer.contentsScale = renderer.scale
        CATransaction.commit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusion { NotificationCenter.default.removeObserver(occlusion) }
        occlusion = nil
        if let window {
            // Hidden behind other windows or minimised: stop drawing entirely.
            occlusion = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window else { return }
                    if window.occlusionState.contains(.visible) { self.wake() } else { self.stop() }
                }
            }
        }
        if window == nil {
            stop()
        } else {
            wake()
        }
    }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
        wake()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuildIfNeeded()
        wake()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        renderer = nil
        rebuildIfNeeded()
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    /// Back to full rate: something changed that the bar should answer.
    func wake() {
        settledFrames = 0
        guard let window, window.occlusionState.contains(.visible) else { return }
        if link == nil {
            let link = displayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
            last = 0
        }
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
    }

    private func rebuildIfNeeded() {
        let barWidth = bounds.width - StorageBarRenderer.margin.side * 2
        guard barWidth > 40 else { return }
        let scale = window?.backingScaleFactor ?? 2
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if let renderer, renderer.width == barWidth.rounded(.down), renderer.scale == min(2, scale), renderer.isDark == isDark { return }
        let kinds = StorageKind.allCases
        renderer = StorageBarRenderer(width: barWidth, scale: scale, hues: kinds.map { isDark ? $0.hue : $0.lightHue }, isDark: isDark)
        // On paper the glow is a tint, not light: keep it faint.
        glowLayer.opacity = isDark ? 0.7 : 0.35
        trackLayer.borderColor = isDark ? CGColor(gray: 1, alpha: 0.07) : CGColor(gray: 0, alpha: 0.08)
        layOutLayers()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = last == 0 ? 1.0 / 60 : min(0.05, max(1.0 / 240, now - last))
        last = now
        clock += reduceMotion ? 0 : dt
        let snap = !started
        started = true
        guard let renderer else {
            rebuildIfNeeded()
            return
        }

        let kinds = StorageKind.allCases
        let phase = store.phase
        let scanning = phase == .scanning
        if scanning {
            if scanStart == nil { scanStart = now }
        } else {
            scanStart = nil
        }

        // What each part should measure this frame.
        var moving = false
        let fast = scanning && (now - (scanStart ?? now)) < 0.6
        for (index, kind) in kinds.enumerated() {
            let target = Double(barTarget(for: kind, phase: phase)) / 1e9
            moving = sizes[index].step(to: target, k: fast ? 60 : 150, c: fast ? 15.5 : 24.5, dt: dt, snap: snap || reduceMotion) || moving
        }

        let looking = phase == .idle ? hover : -1
        for index in focus.indices {
            moving = focus[index].step(to: looking == index ? 1 : 0, k: 340, c: 37, dt: dt, snap: snap) || moving
        }
        moving = dim.step(to: looking >= 0 ? 1 : 0, k: 340, c: 37, dt: dt, snap: snap) || moving
        moving = scanGlow.step(to: scanning ? 1 : 0, k: 120, c: 22, dt: dt, snap: snap) || moving

        publishReadout()

        var spill = -1
        if case .cleaning(let clean) = phase, !reduceMotion {
            spill = clean.kind.rawValue
        }
        let output = renderer.draw(StorageBarRenderer.Frame(
            sizes: sizes.map(\.x),
            focus: focus.map { min(1, max(0, $0.x)) },
            dim: min(1, max(0, dim.x)),
            scan: min(1, max(0, scanGlow.x)),
            spill: spill,
            disk: Double(store.capacity) / 1e9,
            dt: dt,
            t: clock
        ))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.contents = output.glow
        cellsLayer.contents = output.cells
        overlayLayer.contents = output.overlay
        let barHeight = StorageBarRenderer.height
        for (index, layer) in fillLayers.enumerated() {
            if index < output.fills.count {
                let fill = output.fills[index]
                layer.isHidden = false
                layer.frame = flip(fill.rect, in: barHeight)
                layer.backgroundColor = fill.color
            } else {
                layer.isHidden = true
            }
        }
        CATransaction.commit()

        // Settled, it stops drawing altogether: hover, a scan, or a clear wakes it.
        let busy = moving || output.isWarm || phase != .idle
        if busy {
            settledFrames = 0
        } else {
            settledFrames += 1
            if settledFrames >= 2 { stop() }
        }
    }

    /// While a clear runs, the part drains in folder-sized lumps over at least
    /// the clear's own length, however fast the files actually go.
    private func barTarget(for kind: StorageKind, phase: StorageStore.Phase) -> Int64 {
        let live = store.bytes(of: kind)
        guard case .cleaning(let clean) = phase, clean.kind == kind, let started = store.cleanStarted else { return live }
        let from = Double(store.cleanFrom)
        let u = min(1, max(0, Date.now.timeIntervalSince(started) / clean.seconds))
        let steps = 9.0
        let base = (u * steps).rounded(.down)
        let lumpy = base / steps + min(1, max(0, (u * steps - base - 0.3) / 0.7)) / steps
        let eased = 1 - pow(1 - lumpy, 1.6)
        return Int64(from + (Double(live) - from) * eased)
    }

    private func publishReadout() {
        let total = sizes.reduce(0) { $0 + max(0, $1.x) }
        let used = StorageFormat.gb(total)
        if readout.used != used { readout.used = used }
        for index in sizes.indices {
            let text = StorageFormat.gb(max(0, sizes[index].x))
            if readout.sizes[index] != text { readout.sizes[index] = text }
        }
    }
}
