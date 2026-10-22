import SwiftUI

/// Calls out keys sitting in plain text in a shell profile.
struct PlaintextBanner: View {
    let count: Int
    let review: () -> Void

    var body: some View {
        Button(action: review) {
            HStack(spacing: Metrics.spacingS) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("\(count) \(count == 1 ? "key is" : "keys are") in plain text in your shell profile")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Review")
                    .foregroundStyle(.tint)
            }
            .font(.callout)
            .padding(.horizontal, Metrics.spacingL)
            .padding(.vertical, Metrics.spacingS)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(.orange.opacity(0.08))
    }
}
