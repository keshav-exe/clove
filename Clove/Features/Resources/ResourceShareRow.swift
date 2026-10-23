import SwiftUI

struct ResourceShareRow: View {
    let agent: AgentApp
    var file: String?
    let state: ResourceSharing.State
    let toggle: @MainActor (Bool) -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            Text(agent.title)
            if let file {
                Text(file)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Metrics.spacingM)
            switch state {
            case .original:
                Text("Original")
                    .foregroundStyle(.secondary)
            case .ownCopy:
                Text("Has its own version")
                    .foregroundStyle(.secondary)
                    .help("This agent already has a different file with this name. Clove leaves it alone.")
            case .linked, .absent:
                Toggle(agent.title, isOn: Binding(get: { state == .linked }, set: toggle))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
        .font(.callout)
    }
}
