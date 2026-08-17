import SwiftUI

struct OnboardingPrivacyStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(PrivacyPromise.all) { promise in
                PrivacyPromiseRow(promise: promise)
            }
        }
    }
}
