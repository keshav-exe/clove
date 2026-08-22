import SwiftUI

struct OnboardingPrivacyStep: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(PrivacyPromise.all) { promise in
                    FeatureHighlightRow(
                        highlight: FeatureHighlight(
                            symbolName: promise.symbolName,
                            title: promise.title,
                            detail: promise.detail
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
    }
}
