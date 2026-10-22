import SwiftUI

/// Switches that make a slash command or subagent available to other agents,
/// by linking rather than copying, so edits reach all of them.
struct ResourceShareSection: View {
    @Environment(AppModel.self) private var model
    let resource: AgentResource

    @State private var states: [AgentApp: ResourceSharing.State] = [:]
    private let sharing = ResourceSharing()

    var body: some View {
        let agents = sharing.folders(for: resource).keys.sorted()

        if agents.count > 1 {
            SkillDetailSection(title: "Use In") {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    ForEach(agents) { agent in
                        ResourceShareRow(agent: agent, state: states[agent] ?? .absent, toggle: { toggle(agent, $0) })
                    }
                    Text("Clove links to this file instead of copying it, so changes show up for every agent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .task(id: "\(resource.id)#\(model.manager.revision)") {
                reload(agents)
            }
        }
    }

    private func reload(_ agents: [AgentApp]) {
        var next: [AgentApp: ResourceSharing.State] = [:]
        for agent in agents {
            next[agent] = sharing.state(of: resource, for: agent)
        }
        states = next
    }

    private func toggle(_ agent: AgentApp, _ isOn: Bool) {
        do {
            if isOn {
                try sharing.share(resource, with: agent)
            } else {
                try sharing.unshare(resource, from: agent)
            }
            states[agent] = sharing.state(of: resource, for: agent)
            Task { await model.refresh() }
        } catch {
            model.manager.failure = ManagerFailure(title: "Couldn't change \(agent.title)", error: error)
        }
    }
}
