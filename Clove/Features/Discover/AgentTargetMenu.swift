import SwiftUI

/// Picks which agents a new install is linked into. The choice is remembered.
struct AgentTargetMenu: View {
    @Binding var targets: Set<AgentTarget>

    var body: some View {
        Menu {
            ForEach(AgentTarget.allCases) { target in
                Toggle(target.title, isOn: binding(for: target))
            }
            Divider()
            Text("Installed once in ~/.agents/skills and linked into each agent.")
        } label: {
            Text(label)
        }
        .menuStyle(.button)
        .menuIndicator(.visible)
        .buttonStyle(.glass)
        .fixedSize()
        .help("Choose which agents get this skill")
    }

    private var label: String {
        let chosen = AgentTarget.allCases.filter(targets.contains)
        switch chosen.count {
        case 0: return "No Agents"
        case AgentTarget.allCases.count: return "All Agents"
        default: return chosen.map(\.title).formatted(.list(type: .and))
        }
    }

    private func binding(for target: AgentTarget) -> Binding<Bool> {
        Binding {
            targets.contains(target)
        } set: { isOn in
            if isOn {
                targets.insert(target)
            } else {
                targets.remove(target)
            }
        }
    }
}
