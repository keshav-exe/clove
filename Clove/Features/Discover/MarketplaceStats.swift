import SwiftUI

/// Installs, stars, and age in one quiet row.
struct MarketplaceStats: View {
    let skill: MarketplaceSkill
    let page: SkillPageDetails?

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingXL) {
            MarketplaceStat(title: "Installs") {
                Text(skill.installs, format: .number.notation(.compactName))
            }
            if let stars = page?.gitHubStars {
                MarketplaceStat(title: "Stars") {
                    Text(stars)
                }
            }
            if let firstSeen = page?.firstSeen {
                MarketplaceStat(title: "First Seen") {
                    Text(firstSeen)
                }
            }
            if skill.weeklyInstalls.count > 1 {
                MarketplaceStat(title: "8 Weeks") {
                    Sparkline(values: skill.weeklyInstalls)
                        .frame(width: 64, height: 16)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
