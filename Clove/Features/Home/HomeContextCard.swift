import SwiftUI

struct HomeContextCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let tokens = model.resources(of: .instructions).compactMap(\.tokens).reduce(0, +)
        HomeCard(
            title: "Context",
            symbolName: "text.document",
            value: ResourceKind.contextKinds.map { model.resources(of: $0).count }.reduce(0, +).formatted(),
            caption: "instruction files, rules, commands, and subagents",
            destination: .resources(.instructions)
        ) {
            ForEach(ResourceKind.contextKinds) { kind in
                HomeRow(label: kind.title, value: model.resources(of: kind).count.formatted(), destination: .resources(kind))
            }
            HomeRow(label: "Instruction tokens", value: tokens.formatted(), destination: .resources(.instructions))
        }
    }
}
