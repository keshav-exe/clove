import SwiftUI

struct AgentBadge: View {
    let agent: AgentApp

    var body: some View {
        Text(agent.title)
            .font(.caption.weight(.medium))
            .foregroundStyle(agent.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(agent.tint.opacity(0.13), in: .capsule)
    }
}
