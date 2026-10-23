import SwiftUI

/// The dashboard, or the trending skill picked in Home's list.
struct HomeDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let skill = model.homeTrendingSkill {
            MarketplaceSkillView(skill: skill)
                .id(skill.id)
        } else {
            HomeView()
        }
    }
}
