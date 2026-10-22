import SwiftUI

struct ResourceHeader: View {
    let resource: AgentResource

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text(resource.name)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)

            HStack(spacing: Metrics.spacingS) {
                AgentBadge(agent: resource.agent)
                Label(resource.scope.isGlobal ? "Every project" : resource.scope.title,
                      systemImage: resource.scope.isGlobal ? "globe" : "folder")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            if !resource.summary.isEmpty {
                Text(resource.summary)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
