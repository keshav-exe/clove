import SwiftUI

/// Install count, or the hourly change on the Hot list.
struct DiscoverRowMetric: View {
    let skill: MarketplaceSkill
    let showsChange: Bool

    var body: some View {
        Group {
            if showsChange, let change = skill.change {
                Text(change, format: .number.sign(strategy: .always()))
                    .foregroundStyle(change > 0 ? Color.orange : Color.secondary)
                    .accessibilityLabel("\(change) installs compared to yesterday")
            } else {
                Label {
                    Text(skill.installs, format: .number.notation(.compactName))
                } icon: {
                    Image(systemName: "arrow.down.circle")
                }
                .labelStyle(.titleAndIcon)
                .accessibilityLabel("\(skill.installs) installs")
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }
}
