import SwiftUI

struct DiscoverRow: View {
    let skill: MarketplaceSkill
    /// Leaderboard position. Search results have none.
    let rank: Int?
    let showsChange: Bool
    let isInstalled: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingS) {
            if let rank {
                Text(rank, format: .number)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 18, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.spacingXS) {
                    Text(skill.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)

                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                            .accessibilityLabel("Installed")
                            .help("Installed on this Mac")
                    }
                }

                HStack(spacing: 3) {
                    Text(skill.owner)
                        .lineLimit(1)
                    if skill.isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.small)
                            .accessibilityLabel("Official")
                            .help("Published by the maker of the technology")
                    }
                    Spacer(minLength: Metrics.spacingXS)
                    DiscoverRowMetric(skill: skill, showsChange: showsChange)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .help("\(skill.name) · \(skill.source)")
        .accessibilityElement(children: .combine)
    }
}
