import SwiftUI

struct OnboardingFeatureRow: View {
    let systemImage: String
    var tint: Color = OnboardingStyle.brandDeep
    let title: String
    let detail: String

    var body: some View {
        OnboardingRow(
            systemImage: systemImage,
            tint: tint,
            title: title,
            detail: detail
        )
    }
}
