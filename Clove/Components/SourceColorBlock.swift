import SwiftUI

/// Small source-colored swatch for compact lists like the quick access panel.
struct SourceColorBlock: View {
    let tint: Color
    var size: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
