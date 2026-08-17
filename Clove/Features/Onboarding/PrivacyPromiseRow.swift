import SwiftUI

struct PrivacyPromiseRow: View {
    let promise: PrivacyPromise

    var body: some View {
        OnboardingRow(
            systemImage: promise.symbolName,
            title: promise.title,
            detail: promise.detail
        )
    }
}
