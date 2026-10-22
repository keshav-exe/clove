import SwiftUI

struct MarketplaceInstallProgress: View {
    let phase: SkillManager.Phase

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Metrics.spacingL)
        .padding(.vertical, Metrics.spacingS)
        .glassEffect()
    }

    private var title: String {
        switch phase {
        case .installing: "Installing…"
        case .updating: "Updating…"
        case .removing: "Removing…"
        }
    }
}
