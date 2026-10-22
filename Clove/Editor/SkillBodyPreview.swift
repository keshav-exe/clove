import SwiftUI

struct SkillBodyPreview: View {
    let document: MarkdownDocument

    var body: some View {
        ScrollView {
            if document.isEmpty {
                Text("Nothing to preview yet.")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                MarkdownView(document: document)
                    .padding(Metrics.spacingXL)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.background.secondary)
    }
}
