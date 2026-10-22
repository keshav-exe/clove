import SwiftUI

struct DiscoverDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let skill = model.marketplace.selectedSkill {
                MarketplaceSkillView(skill: skill)
                    .id(skill.id)
            } else {
                ContentUnavailableView(
                    "Pick a Skill",
                    systemImage: "square.and.arrow.down",
                    description: Text("Read its SKILL.md, check its security audits, and install it into your agents.")
                )
            }
        }
        .navigationSplitViewColumnWidth(min: Metrics.detailMinWidth, ideal: 460)
    }
}
