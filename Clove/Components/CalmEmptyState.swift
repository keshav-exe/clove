import SwiftUI

/// An empty state that shows what will fill the space: mockups of the real
/// thing, a plain title, and two sentences. No button, no apology.
struct CalmEmptyState<Art: View>: View {
    let title: String
    let message: String
    @ViewBuilder let art: Art

    var body: some View {
        VStack(spacing: 22) {
            art
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    // No fixedSize here: inside this full-size frame it fed back
                    // into the split view's layout and scrolled the sidebar away.
            }
            .frame(maxWidth: 380)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
