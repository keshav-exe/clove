import SwiftUI

/// Lays chips out left to right and wraps to the next line when space runs out.
struct WrappingTagRow<Content: View>: View {
    let tags: [String]
    @ViewBuilder let content: (String) -> Content

    var body: some View {
        FlowLayout(spacing: Metrics.spacingXS) {
            ForEach(tags, id: \.self) { tag in
                content(tag)
            }
        }
    }
}
