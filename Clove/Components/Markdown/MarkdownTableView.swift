import SwiftUI

struct MarkdownTableView: View {
    let rows: [[AttributedString]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: Metrics.spacingL, verticalSpacing: Metrics.spacingS) {
                ForEach(rows.enumerated(), id: \.offset) { index, row in
                    GridRow {
                        ForEach(row.enumerated(), id: \.offset) { _, cell in
                            Text(cell)
                                .fontWeight(index == 0 ? .semibold : nil)
                                .frame(maxWidth: 280, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if index == 0 {
                        Divider()
                    }
                }
            }
            .font(.callout)
            .padding(.vertical, Metrics.spacingXS)
        }
        .scrollIndicators(.automatic)
    }
}
