import SwiftUI

struct MarkdownListView: View {
    let items: [MarkdownListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            ForEach(items.enumerated(), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingS) {
                    Text(item.marker)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 14, alignment: .trailing)
                    Text(item.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, Double(item.level) * Metrics.spacingL)
            }
        }
    }
}
