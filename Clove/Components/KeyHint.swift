import SwiftUI

/// Small keycap used for inline keyboard hints.
struct KeyHint: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 4))
            .accessibilityHidden(true)
    }
}
