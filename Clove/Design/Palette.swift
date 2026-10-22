import AppKit
import SwiftUI

/// The calm palette: warm paper surfaces, a warm grey ink ramp, one azure
/// accent. Color only where it means something.
enum Palette {
    static let background = Color.dynamic(light: 0xFBFBF9, dark: 0x191917)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x222220)
    static let surfaceMuted = Color.dynamic(light: 0xF1F0ED, dark: 0x2B2A27)
    static let ink = Color.dynamic(light: 0x2B2A26, dark: 0xECEAE3)
    static let inkSecondary = Color.dynamic(light: 0x736F67, dark: 0x9D988D)
    static let inkTertiary = Color.dynamic(light: 0xA6A29A, dark: 0x6F6A60)
    static let accent = Color.dynamic(light: 0x1F6FE5, dark: 0x5AA0FF)
    static let hairline = Color.dynamic(light: 0xEBE9E4, dark: 0x33322D)
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
