import SwiftUI

/// Toggle row with an icon tile and an explanation underneath the title.
struct SettingsToggleRow: View {
    let systemImage: String
    var tint: Color = .accentColor
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
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
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
    }
}
