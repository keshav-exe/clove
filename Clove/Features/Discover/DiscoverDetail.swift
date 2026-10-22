import SwiftUI

struct DiscoverDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let skill = model.marketplace.selectedSkill {
                MarketplaceSkillView(skill: skill)
                    .id(skill.id)
            } else {
                CalmEmptyState(
                    title: "Pick a skill to read",
                    message: "You'll see its SKILL.md, its security audits, and how many people use it. Installing takes one click."
                ) {
                    DiscoverArt()
                }
            }
        }
    }
}
