import SwiftUI

struct SkillDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
