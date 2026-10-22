import SwiftUI

struct MarketplaceSkillHeader: View {
    let skill: MarketplaceSkill
    let detail: MarketplaceDetail?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text(skill.name)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)

                HStack(spacing: Metrics.spacingXS) {
                    Text(skill.source)
                        .textSelection(.enabled)
                    if skill.isOfficial {
                        Label("Official", systemImage: "checkmark.seal.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.blue)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let summary = detail?.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MarketplaceStats(skill: skill, page: detail?.page)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
