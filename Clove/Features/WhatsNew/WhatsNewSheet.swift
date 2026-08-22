import SwiftUI

struct WhatsNewSheet: View {
    let release: WhatsNewRelease
    var onFinish: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FeatureSheet(
            symbolName: release.symbolName,
            title: release.title,
            subtitle: release.subtitle,
            continueTitle: "Continue",
            onContinue: finish
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(release.features) { feature in
                        FeatureHighlightRow(highlight: feature)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

#Preview {
    WhatsNewSheet(release: WhatsNewCatalog.latest!)
}
