import SwiftUI

struct MarketplaceStat<Value: View>: View {
    let title: String
    @ViewBuilder let value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            value
                .font(.body.weight(.medium))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
