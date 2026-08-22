import SwiftUI

struct FeatureHighlightRow: View {
    let highlight: FeatureHighlight

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(.body.weight(.medium))

                Text(highlight.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
            }
        } icon: {
            Image(systemName: highlight.symbolName)
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
        }
        .labelStyle(.titleAndIcon)
        .accessibilityElement(children: .combine)
    }
}
