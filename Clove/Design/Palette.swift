import AppKit
import SwiftUI

/// The web design system shared with kshv.me, Shotput, the sandbox, and the
/// Clove site: neutral paper, graphite chrome, and colour only where it
/// means something (icons, marks, links). Values mirror clove-web/src/styles.css.
enum Palette {
    // Neutrals on one hue (265°) with a whisper of chroma, so greys stay cool
    // and even. Dark mode sits at L 0.235 like native Mac content areas, not
    // near-black. Every text token clears WCAG AA (4.5:1) on every surface it
    // sits on; tertiary is decorative (placeholders, chevrons) and clears 3:1.
    static let background = Color.oklch(light: (0.985, 0.002, 265), dark: (0.235, 0.004, 265))
    /// A panel: the raised, brightest surface, set inside a card.
    static let surface = Color.oklch(light: (1, 0, 0), dark: (0.3, 0.004, 265))
    /// A card: the soft surface panels sit on.
    static let surfaceMuted = Color.oklch(light: (0.965, 0.003, 265), dark: (0.262, 0.004, 265))
    static let surfaceSunken = Color.oklch(light: (0.945, 0.003, 265), dark: (0.215, 0.004, 265))
    /// 17:1 on paper, 15:1 on the dark page.
    static let ink = Color.oklch(light: (0.2, 0.004, 265), dark: (0.97, 0.002, 265))
    /// 6:1 on paper, 6.6:1 on the brightest dark panel.
    static let inkSecondary = Color.oklch(light: (0.49, 0.008, 265), dark: (0.77, 0.006, 265))
    /// Decorative only: about 3:1.
    static let inkTertiary = Color.oklch(light: (0.66, 0.008, 265), dark: (0.62, 0.006, 265))
    static let hairline = Color.oklch(light: (0.91, 0.004, 265), dark: (0.36, 0.004, 265))
    /// Links and accent text: 5:1 on white, 5.9:1 on the dark panel.
    static let accent = Color.oklch(light: (0.55, 0.21, 262), dark: (0.74, 0.14, 255))
    /// Running, installed, passed, done: the healthy states.
    static let mint = Color.dynamic(light: 0x13A87C, dark: 0x4FE0AE)
    static let destructive = Color(hex: 0xE5484D)

    /// The card's hairline ring, drawn as a stroke.
    static let ring = Color.dynamic(light: 0x000000, dark: 0xFFFFFF, lightOpacity: 0.06, darkOpacity: 0.06)

    /// Graphite chrome, the same in both themes: toolbars, the storage instrument.
    enum Chrome {
        static let fill = Color(hex: 0x1B1C1F)
        static let raised = Color(hex: 0x2A2B30)
        static let ink = Color(hex: 0xF4F4F5)
        static let muted = Color(hex: 0xF4F4F5).opacity(0.6)
        static let faint = Color(hex: 0xF4F4F5).opacity(0.32)
        static let lift = Color.white.opacity(0.075)
    }

    /// Vivid hues for icons and marks only, deeper on paper so they keep their contrast.
    enum Vivid {
        static let orange = Color.dynamic(light: 0xE86700, dark: 0xFF8717)
        static let pink = Color.dynamic(light: 0xE03694, dark: 0xFF5BB3)
        static let violet = Color.dynamic(light: 0x8848E1, dark: 0xAC70FF)
        static let blue = Color.dynamic(light: 0x0278E7, dark: 0x3D9EFF)
        static let green = Color.dynamic(light: 0x00A33A, dark: 0x37DD66)
        static let cyan = Color.dynamic(light: 0x00A0BA, dark: 0x00D6F5)
        static let yellow = Color.dynamic(light: 0xDBA000, dark: 0xFFCF00)
        static let red = Color.dynamic(light: 0xE23532, dark: 0xFF423E)
    }
}

extension Color {
    /// OKLCH (lightness 0...1, chroma, hue in degrees), per appearance. Lightness
    /// is perceptual, so contrast between two tokens is the gap in their L.
    static func oklch(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        let lightColor = NSColor(oklch: light)
        let darkColor = NSColor(oklch: dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        })
    }

    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Resolves per appearance, so the palette lives in code in one place.
    static func dynamic(light: UInt, dark: UInt, lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light).opacity(isDark ? darkOpacity : lightOpacity))
        })
    }
}

extension NSColor {
    /// OKLCH to sRGB, clamped into gamut.
    convenience init(oklch value: (Double, Double, Double)) {
        let (lightness, chroma, hue) = value
        let a = chroma * cos(hue * .pi / 180)
        let b = chroma * sin(hue * .pi / 180)
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        let linear = [
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
        ].map { min(1, max(0, $0)) }
        let encoded = linear.map { $0 <= 0.0031308 ? 12.92 * $0 : 1.055 * pow($0, 1 / 2.4) - 0.055 }
        self.init(srgbRed: encoded[0], green: encoded[1], blue: encoded[2], alpha: 1)
    }
}
