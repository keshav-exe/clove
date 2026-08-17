import SwiftUI

/// Row with an icon tile, a description, and a trailing control.
struct SettingsActionRow<Trailing: View>: View {
    let systemImage: String
    var tint: Color = .accentColor
    let title: String
    var detail: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            IconTile(systemImage: systemImage, tint: tint, size: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Metrics.spacingS)

            trailing
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
    }
}
