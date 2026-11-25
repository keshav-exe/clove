import AppKit
import SwiftUI

/// The island's cards: see-through glass (a light wash over the island and a
/// hairline edge) so the island shows through. Something that's running gets
/// a breathing glow along its bottom edge, in the colours of its app's icon.
struct NotchGlass: ViewModifier {
    var radius: CGFloat = 18
    /// Colours to breathe along the bottom edge while something runs.
    var breathing: [Color]?
    var isHovered = false
    @Environment(\.notchCardFrost) private var cardFrost

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    // As the island clears, each card frosts over instead, the
                    // way Control Center's tiles do, so its text stays readable
                    // over whatever's behind.
                    if cardFrost > 0 {
                        Color.clear
                            .glassEffect(.regular, in: shape)
                            .opacity(cardFrost)
                        shape.fill(.black.opacity(0.22 * cardFrost))
                    }
                    shape.fill(Color.primary.opacity(isHovered ? 0.075 : 0.05))
                    if let breathing, !breathing.isEmpty {
                        BreathingGlow(colors: breathing)
                            .clipShape(shape)
                            .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(isHovered ? 0.1 : 0.065), lineWidth: 0.5)
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

extension EnvironmentValues {
    /// How much frost the cards carry themselves: none while the island is
    /// frosted, all of it once the island is clear.
    @Entry var notchCardFrost: Double = 0
}

extension View {
    /// The board's cards. Pass `breathing` while the card's thing is running.
    func notchCard(radius: CGFloat = 18, isHovered: Bool = false, breathing: [Color]? = nil) -> some View {
        modifier(NotchGlass(radius: radius, breathing: breathing, isHovered: isHovered))
    }
}

/// Light pooled along the bottom of a card, drifting and breathing: three
/// soft blooms of the app's colours slide back and forth along the edge,
/// swelling and settling on a slow, out-of-step rhythm, and fade upward into
/// the glass. Only drawn while something runs; still with Reduce Motion.
struct BreathingGlow: View {
    let colors: [Color]
    /// Holds one pose, for pictures of a card rather than the card itself.
    var isStill = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let still = reduceMotion || isStill
        TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { context in
            let time = still ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                canvas.addFilter(.blur(radius: size.height * 0.26))
                for index in 0..<3 {
                    let colour = colors[index % colors.count]
                    let phase = Double(index) * 2.3
                    // Each bloom drifts across at its own pace...
                    let x = 0.5 + 0.36 * sin(time * (0.21 + 0.07 * Double(index)) + phase)
                    // ...and breathes: about five seconds in and out.
                    let breath = 0.5 + 0.5 * sin(time * 1.15 + phase * 1.4)
                    let width = size.width * (0.42 + 0.22 * breath)
                    let height = size.height * (0.5 + 0.28 * breath)
                    let rect = CGRect(
                        x: size.width * x - width / 2,
                        y: size.height - height * 0.55,
                        width: width,
                        height: height
                    )
                    canvas.fill(Path(ellipseIn: rect), with: .color(colour.opacity(0.5 + 0.3 * breath)))
                }
            }
        }
        // Progressive: full strength at the edge, gone by the middle.
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0.25), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The colours an app's icon is made of: its two strongest hues, brightened
/// to read on the dark island. Grey icons get nothing, and fall back.
@MainActor
enum IconPalette {
    private static var cache: [String: [Color]] = [:]

    static func colors(forApp path: String) -> [Color] {
        if let cached = cache[path] { return cached }
        let found = colors(of: NSWorkspace.shared.icon(forFile: path))
        cache[path] = found
        return found
    }

    nonisolated static func colors(of image: NSImage) -> [Color] {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let side = 28
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Twelve hue buckets, each weighted by how colourful its pixels are.
        struct Bucket { var weight = 0.0; var r = 0.0; var g = 0.0; var b = 0.0 }
        var buckets = [Bucket](repeating: Bucket(), count: 12)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.6 else { continue }
            let r = Double(pixels[index]) / 255 / alpha, g = Double(pixels[index + 1]) / 255 / alpha, b = Double(pixels[index + 2]) / 255 / alpha
            let high = max(r, g, b), low = min(r, g, b)
            let saturation = high > 0 ? (high - low) / high : 0
            guard saturation > 0.28, high > 0.25 else { continue }
            var hue: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            NSColor(srgbRed: r, green: g, blue: b, alpha: 1).getHue(&hue, saturation: &s, brightness: &v, alpha: &a)
            let slot = min(Int(hue * 12), 11)
            buckets[slot].weight += saturation
            buckets[slot].r += r * saturation
            buckets[slot].g += g * saturation
            buckets[slot].b += b * saturation
        }
        let total = buckets.reduce(0) { $0 + $1.weight }
        guard total > 6 else { return [] }
        return buckets
            .filter { $0.weight > total * 0.12 }
            .sorted { $0.weight > $1.weight }
            .prefix(2)
            .map { bucket in
                let colour = NSColor(srgbRed: bucket.r / bucket.weight, green: bucket.g / bucket.weight, blue: bucket.b / bucket.weight, alpha: 1)
                var hue: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
                colour.getHue(&hue, saturation: &s, brightness: &v, alpha: &a)
                return Color(hue: hue, saturation: min(max(s, 0.5), 0.85), brightness: max(v, 0.85))
            }
    }
}

extension AgentSession {
    /// The colours its card breathes in: the host app's icon, or the agent's own.
    @MainActor
    var glowColors: [Color] {
        if let host, case let found = IconPalette.colors(forApp: host.bundlePath), !found.isEmpty {
            return found
        }
        switch agent {
        case .claude: return [Color(hue: 0.04, saturation: 0.62, brightness: 0.92), Color(hue: 0.08, saturation: 0.5, brightness: 0.95)]
        case .codex: return [Color(hue: 0.6, saturation: 0.55, brightness: 0.95), Color(hue: 0.75, saturation: 0.45, brightness: 0.9)]
        }
    }
}
