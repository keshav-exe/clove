import SwiftUI

struct ShortcutHintRow: View {
    let keys: String
    let detail: String

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            Text(keys)
                .font(.callout.monospaced())
                .frame(width: 46, alignment: .leading)

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
        .accessibilityElement(children: .combine)
    }
}
