import SwiftUI

struct ResourceRow: View {
    @Environment(AppModel.self) private var model
    let resource: AgentResource

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Metrics.spacingXS) {
                Text(title)
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
                Text(meta)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(resource.fileURL.path(percentEncoded: false))
    }

    /// A project's AGENTS.md is known by its project, not by a file name every
    /// project shares.
    private var title: String {
        if resource.kind == .instructions, case .project(let project) = resource.scope {
            return project
        }
        return resource.name
    }

    private var meta: String {
        var parts: [String] = []
        if title != resource.name {
            parts.append(resource.name)
        } else if case .project(let project) = resource.scope {
            parts.append(project)
        }
        if let tokens = resource.tokens {
            parts.append("\(tokens.formatted()) tokens")
        }
        if let usage = usageText {
            parts.append(usage)
        }
        return parts.joined(separator: " · ")
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
