import SwiftUI

/// Scrolling, top-aligned page with the same margins as a skill's detail.
struct CleanupPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                content
            }
            .padding(Metrics.spacingXL)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
