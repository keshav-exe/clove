import SwiftUI

struct PanelSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: Metrics.spacingXS) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(Metrics.headerTracking)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Text("\(count)")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.quaternary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 1)
        .padding(.bottom, 1)
        .accessibilityAddTraits(.isHeader)
    }
}
