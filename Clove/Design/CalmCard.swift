import SwiftUI

/// A paper card: surface fill, hairline border, the faintest shadow.
struct CalmCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Palette.surface, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
