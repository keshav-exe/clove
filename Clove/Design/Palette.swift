import AppKit
import SwiftUI

/// The web design system shared with kshv.me, Shotput, the sandbox, and the
/// Clove site: neutral paper, graphite chrome, and colour only where it
/// means something (icons, marks, links). Values mirror clove-web/src/styles.css.
enum Palette {
    static let background = Color.dynamic(light: 0xFAFAFA, dark: 0x0A0B0C)
    /// A panel: the raised, brightest surface, set inside a card.
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1F1F21)
    /// A card: the soft surface panels sit on.
    static let surfaceMuted = Color.dynamic(light: 0xF4F4F5, dark: 0x151516)
    static let surfaceSunken = Color.dynamic(light: 0xEFEFF0, dark: 0x121213)
    static let ink = Color.dynamic(light: 0x0A0A0A, dark: 0xFAFAFA)
    static let inkSecondary = Color.dynamic(light: 0x5C5C5F, dark: 0x8E8E93)
    /// Decorative only: below 4.5:1 on paper.
    static let inkTertiary = Color.dynamic(light: 0xA1A1A6, dark: 0x56565B)
    static let hairline = Color.dynamic(light: 0xE6E6E8, dark: 0x262628)
    static let accent = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)
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
