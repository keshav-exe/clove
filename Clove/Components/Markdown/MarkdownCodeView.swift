import SwiftUI

struct MarkdownCodeView: View {
    let text: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.callout.monospaced())
                .fixedSize()
                .padding(Metrics.spacingM)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Metrics.controlRadius))
    }
}
