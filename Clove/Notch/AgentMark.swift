import AppKit
import SwiftUI

/// What sits in the notch's right ear while one agent works.
enum AgentMark: String, CaseIterable, Identifiable, Sendable {
    /// A still dot: the quietest, and the default.
    case dot
    /// The dot slowly swells and fades.
    case breathe
    /// A short arc circling a faint ring.
    case orbit
    /// Three bars rising and falling in turn.
    case bars
    /// Rings spreading out from the dot.
    case ripple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dot: "Dot"
        case .breathe: "Breathe"
        case .orbit: "Orbit"
        case .bars: "Bars"
        case .ripple: "Ripple"
        }
    }
}

/// An agent mark, 16pt square. The moving ones run on Core Animation, so the
/// island's SwiftUI view isn't redrawn every frame while an agent works. With
/// Reduce Motion each settles on a still frame.
struct AgentMarkView: View {
    static let size: CGFloat = 16

    let mark: AgentMark
    var color: Color = Palette.mint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AgentMarkLayers(mark: mark, color: color, animates: !reduceMotion)
            .frame(width: Self.size, height: Self.size)
            .accessibilityHidden(true)
    }
}

private struct AgentMarkLayers: NSViewRepresentable {
    let mark: AgentMark
    let color: Color
    let animates: Bool

    func makeNSView(context: Context) -> AgentMarkLayerView {
        AgentMarkLayerView()
    }

    func updateNSView(_ view: AgentMarkLayerView, context: Context) {
        view.show(mark, color: color.resolve(in: context.environment).cgColor, animates: animates)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AgentMarkLayerView, context: Context) -> CGSize? {
        CGSize(width: AgentMarkView.size, height: AgentMarkView.size)
    }
}

final class AgentMarkLayerView: NSView {
    private var shown: (mark: AgentMark, color: CGColor, animates: Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: NSSize { NSSize(width: AgentMarkView.size, height: AgentMarkView.size) }

    /// Purely decorative: clicks go to the island underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        layer?.sublayers?.forEach { $0.contentsScale = scale }
    }

    func show(_ mark: AgentMark, color: CGColor, animates: Bool) {
        if let shown, shown.mark == mark, shown.color == color, shown.animates == animates { return }
        shown = (mark, color, animates)
        guard let host = layer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        host.sublayers?.forEach { $0.removeFromSuperlayer() }
        let marks = Self.layers(for: mark, color: color, animates: animates)
        let scale = window?.backingScaleFactor ?? 2
        for mark in marks {
            mark.contentsScale = scale
            host.addSublayer(mark)
        }
        CATransaction.commit()
    }

    // MARK: Drawing

    private static let box = CGRect(x: 0, y: 0, width: AgentMarkView.size, height: AgentMarkView.size)
    private static let center = CGPoint(x: box.midX, y: box.midY)

    private static func layers(for mark: AgentMark, color: CGColor, animates: Bool) -> [CALayer] {
        switch mark {
        case .dot:
            return [dot(diameter: 6, color: color)]
        case .breathe:
            let dot = dot(diameter: 6, color: color)
            if animates {
                let scale = basic("transform.scale", from: 0.65, to: 1)
                let fade = basic("opacity", from: 0.5, to: 1)
                dot.add(repeating([scale, fade], duration: 2.7, autoreverses: true), forKey: "breathe")
            }
            return [dot]
        case .orbit:
            let track = ring(diameter: 10, lineWidth: 1.75, color: color.copy(alpha: 0.22) ?? color)
            let arc = ring(diameter: 10, lineWidth: 1.75, color: color)
            arc.strokeEnd = 0.28
            if animates {
                let spin = basic("transform.rotation.z", from: 0, to: -2 * Double.pi)
                arc.add(repeating([spin], duration: 1.1, timing: .linear), forKey: "orbit")
            }
            return [track, arc]
        case .bars:
            let rest: [Double] = [0.5, 1, 0.7]
            return (0..<3).map { index in
                let bar = CALayer()
                bar.bounds = CGRect(x: 0, y: 0, width: 2, height: 10)
                bar.position = CGPoint(x: center.x + CGFloat(index - 1) * 4, y: center.y)
                bar.cornerRadius = 1
                bar.backgroundColor = color
                if animates {
                    let rise = basic("transform.scale.y", from: 0.3, to: 1)
                    let pulse = repeating([rise], duration: 0.5, autoreverses: true)
                    pulse.timeOffset = Double(index) * 0.17
                    bar.add(pulse, forKey: "bars")
                } else {
                    bar.transform = CATransform3DMakeScale(1, rest[index], 1)
                }
                return bar
            }
        case .ripple:
            let core = dot(diameter: 5, color: color)
            let waves = (0..<2).map { index in
                let wave = ring(diameter: 14, lineWidth: 1.2, color: color)
                if animates {
                    let grow = basic("transform.scale", from: 5.0 / 14, to: 1)
                    let fade = basic("opacity", from: 0.8, to: 0)
                    let spread = repeating([grow, fade], duration: 2, timing: .easeOut)
                    spread.timeOffset = Double(index)
                    wave.add(spread, forKey: "ripple")
                    // Starts out of sight; the animation fades it in.
                    wave.opacity = 0
                } else {
                    wave.opacity = index == 0 ? 0.35 : 0
                    wave.transform = CATransform3DMakeScale(0.75, 0.75, 1)
                }
                return wave
            }
            return waves + [core]
        }
    }

    private static func dot(diameter: CGFloat, color: CGColor) -> CALayer {
        let dot = CALayer()
        dot.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        dot.position = center
        dot.cornerRadius = diameter / 2
        dot.backgroundColor = color
        return dot
    }

    /// A circle stroked from twelve o'clock, filling the box so it spins and
    /// scales about its centre.
    private static func ring(diameter: CGFloat, lineWidth: CGFloat, color: CGColor) -> CAShapeLayer {
        let ring = CAShapeLayer()
        ring.frame = box
        let path = CGMutablePath()
        path.addArc(center: center, radius: diameter / 2, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        ring.path = path
        ring.fillColor = nil
        ring.strokeColor = color
        ring.lineWidth = lineWidth
        ring.lineCap = .round
        return ring
    }

    private static func basic(_ keyPath: String, from: Double, to: Double) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        return animation
    }

    private static func repeating(
        _ animations: [CAAnimation],
        duration: CFTimeInterval,
        autoreverses: Bool = false,
        timing: CAMediaTimingFunctionName = .easeInEaseOut
    ) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.autoreverses = autoreverses
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: timing)
        group.isRemovedOnCompletion = false
        return group
    }
}
