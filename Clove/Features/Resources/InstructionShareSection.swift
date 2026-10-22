import SwiftUI

/// Which agents read this instruction file, with switches to point the
/// others at it instead of keeping separate copies in step by hand.
struct InstructionShareSection: View {
    @Environment(AppModel.self) private var model
    let resource: AgentResource

    @State private var states: [AgentApp: ResourceSharing.State] = [:]
    private let sharing = InstructionSharing()

    var body: some View {
        let files = sharing.files(for: resource)
        let agents = files.keys.sorted()

        if !agents.isEmpty, resource.summary != "Empty file" {
            SkillDetailSection(title: "Read By") {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    ForEach(agents) { agent in
                        ResourceShareRow(
                            agent: agent,
                            file: files[agent]?.lastPathComponent,
                            state: states[agent] ?? .absent,
                            toggle: { toggle(agent, $0) }
                        )
                    }
                    Text("Turning one on links its file, like CLAUDE.md, to this one. Edit here and every agent reads the change.")
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
