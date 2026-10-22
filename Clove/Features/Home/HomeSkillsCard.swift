import SwiftUI

struct HomeSkillsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HomeCard(
            title: "Skills",
            symbolName: "square.stack.3d.up",
            value: model.catalog.count.formatted(),
            caption: "on this Mac",
            destination: .library(.all)
        ) {
            ForEach(model.availableSources.prefix(4), id: \.self) { source in
                HomeRow(label: source.sectionTitle, value: model.count(of: .source(source)).formatted(), destination: .library(.source(source)))
            }
        }
    }
}
