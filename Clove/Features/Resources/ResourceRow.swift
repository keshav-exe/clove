import SwiftUI

struct ResourceRow: View {
    @Environment(AppModel.self) private var model
    let resource: AgentResource

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Metrics.spacingXS) {
                Text(resource.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if resource.problem != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                        .accessibilityLabel("Has a problem")
                }
            }

            if !resource.summary.isEmpty {
                Text(resource.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: Metrics.spacingS) {
                AgentBadge(agent: resource.agent)
                if let tokens = resource.tokens {
                    Text("\(tokens, format: .number) tokens")
                        .monospacedDigit()
                }
                if let usage = usageText {
                    Text(usage)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only kinds Clove can see being used get a usage line.
    private var usageText: String? {
        guard resource.hasObservableUsage, let report = model.cleanup.usage.value else { return nil }
        if let date = report.lastUsed[resource.usageKey] {
            return "Used " + date.formatted(.relative(presentation: .named))
        }
        return "Not used yet"
    }
}
