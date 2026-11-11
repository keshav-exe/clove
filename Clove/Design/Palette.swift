import AppKit
import SwiftUI

/// The calm palette, cold: cool paper surfaces, a slate ink ramp, an azure
/// accent, and mint for things that are fine. Color only where it means something.
enum Palette {
    static let background = Color.dynamic(light: 0xF8FAFC, dark: 0x15181C)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1E2227)
    static let surfaceMuted = Color.dynamic(light: 0xEEF2F7, dark: 0x272C32)
    static let ink = Color.dynamic(light: 0x1E2530, dark: 0xE8EDF3)
    static let inkSecondary = Color.dynamic(light: 0x64707F, dark: 0x9AA5B2)
    static let inkTertiary = Color.dynamic(light: 0x9AA5B2, dark: 0x67727F)
    static let accent = Color.dynamic(light: 0x1F6FE5, dark: 0x5AA0FF)
    /// Running, installed, passed, done: the healthy states.
    static let mint = Color.dynamic(light: 0x12A87C, dark: 0x4FE0AE)
    static let hairline = Color.dynamic(light: 0xE2E8EF, dark: 0x30363D)
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
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
}
