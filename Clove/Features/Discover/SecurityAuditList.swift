import SwiftUI

struct SecurityAuditList: View {
    let audits: [SkillAudit]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            ForEach(audits) { audit in
                HStack(spacing: Metrics.spacingS) {
                    Image(systemName: symbol(for: audit.verdict))
                        .foregroundStyle(tint(for: audit.verdict))
                        .frame(width: 16)
                    Text(audit.provider)
                    Spacer(minLength: Metrics.spacingS)
                    Text(audit.status)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.callout)
    }

    private func symbol(for verdict: SkillAudit.Verdict) -> String {
        switch verdict {
        case .pass: "checkmark.shield.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .fail: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func tint(for verdict: SkillAudit.Verdict) -> Color {
        switch verdict {
        case .pass: .green
        case .warn: .orange
        case .fail: .red
        case .unknown: .secondary
        }
    }
}
