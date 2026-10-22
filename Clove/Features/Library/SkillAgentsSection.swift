import SwiftUI

/// Which agents can use this skill, as switches. Only shown for skills with a
/// shared copy in `~/.agents/skills`, since that is what the links point at.
struct SkillAgentsSection: View {
    @Environment(AppModel.self) private var model
    let name: String

    @State private var linked: Set<AgentTarget> = []
    @State private var isShared = false

    var body: some View {
        Group {
            if isShared {
                SkillDetailSection(title: "Use In") {
                    VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                        ForEach(AgentTarget.allCases) { target in
                            Toggle(target.title, isOn: binding(for: target))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .task(id: "\(name)#\(model.manager.revision)") {
            isShared = model.manager.hasSharedCopy(name)
            linked = await model.manager.linkedTargets(for: name)
        }
    }

    private func binding(for target: AgentTarget) -> Binding<Bool> {
        Binding {
            linked.contains(target)
        } set: { isOn in
            if isOn { linked.insert(target) } else { linked.remove(target) }
            Task { await model.manager.setLinked(isOn, name: name, target: target) }
        }
    }
}
