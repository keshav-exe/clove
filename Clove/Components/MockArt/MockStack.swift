import SwiftUI

/// Up to three mockups layered like a loose pile: the back two tilted, dimmed,
/// and a touch smaller, the front one nearly upright. Purely decorative.
struct MockStack<Back: View, Middle: View, Front: View>: View {
    var height: Double = 190
    @ViewBuilder let back: Back
    @ViewBuilder let middle: Middle
    @ViewBuilder let front: Front

    var body: some View {
        ZStack {
            back
                .rotationEffect(.degrees(-7))
                .scaleEffect(0.94)
                .environment(\.mockCardFade, 0.55)
                .offset(x: -46, y: -34)
            middle
                .rotationEffect(.degrees(6))
                .scaleEffect(0.94)
                .environment(\.mockCardFade, 0.6)
                .offset(x: 50, y: -14)
            front
                .rotationEffect(.degrees(-2))
                .offset(y: 26)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
