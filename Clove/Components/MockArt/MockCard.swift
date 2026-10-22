import SwiftUI

/// The frosted card every mockup sits on: it blurs whatever lies behind it, so
/// stacked cards never show each other's text through.
struct MockCard<Content: View>: View {
    var width: Double = 236
    @ViewBuilder let content: Content

    @Environment(\.mockCardFade) private var fade

    var body: some View {
        content
            .opacity(fade)
            .padding(12)
            .frame(width: width, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

extension EnvironmentValues {
    /// How strongly a card's content shows. Cards further back in a stack fade
    /// their content, not their glass, so nothing behind them bleeds through.
    @Entry var mockCardFade: Double = 1
}
