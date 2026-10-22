import SwiftUI

struct HomeToolsCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let brokenHooks = model.resources(of: .hooks).count { $0.problem != nil }
        let exposed = model.secrets.findings.count
        HomeCard(
            title: "Tools & Access",
            symbolName: "server.rack",
            value: model.resources(of: .mcpServers).count.formatted(),
            caption: "MCP servers set up",
            destination: .resources(.mcpServers)
        ) {
            HomeRow(
                label: "Hooks",
                value: brokenHooks > 0 ? "\(brokenHooks) broken" : model.resources(of: .hooks).count.formatted(),
                destination: .resources(.hooks),
                isWarning: brokenHooks > 0
            )
            HomeRow(label: "Permission rules", value: model.resources(of: .permissions).count.formatted(), destination: .resources(.permissions))
            HomeRow(
                label: "Secrets",
                value: exposed > 0 ? "\(exposed) in plain text" : model.secrets.items.count.formatted(),
                destination: .secrets,
                isWarning: exposed > 0
            )
        }
    }
}
