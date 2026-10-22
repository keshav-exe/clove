import SwiftUI

struct HomeTrendingCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let trending = model.marketplace.feeds[.trending]?.value ?? []
        HomeCard(
            title: "Trending on skills.sh",
            symbolName: "chart.line.uptrend.xyaxis",
            value: trending.first?.name ?? "—",
            caption: "most added in the last day",
            destination: .discover
        ) {
            ForEach(trending.dropFirst().prefix(4)) { skill in
                HomeRow(
                    label: skill.name,
                    value: skill.installs.formatted(.number.notation(.compactName)),
                    destination: .discover,
                    action: { openTrending(skill) }
                )
            }
        }
    }

    private func openTrending(_ skill: MarketplaceSkill) {
        model.marketplace.feed = .trending
        model.marketplace.selection = skill.id
    }
}
