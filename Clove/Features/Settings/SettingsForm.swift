import SwiftUI

/// Scrollable settings content area — replaces macOS `Form` for predictable layout.
struct SettingsForm<Content: View>: View {
    var centered = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            Group {
                if centered {
                    content()
                        .frame(maxWidth: SettingsLayout.contentMaxWidth)
                        .frame(maxWidth: .infinity)
                } else {
                    content()
                }
            }
            .padding(.horizontal, Metrics.spacingXL)
            .padding(.top, Metrics.spacingS)
            .padding(.bottom, Metrics.spacingXL)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
