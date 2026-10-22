import SwiftUI

/// One unused skill. The whole row toggles whether it gets removed.
struct CleanupRow: View {
    let candidate: CleanupCandidate
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Metrics.spacingM) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: Metrics.spacingXS) {
                        if case .resource = candidate.item {
                            Text(candidate.kindTitle)
                            Text("·")
                        }
                        LastUsedText(date: candidate.lastUsed)
                        Text("·")
                        Text("\(candidate.tokens, format: .number) tokens")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 3)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isSelected ? 1 : 0.6)
        .accessibilityLabel("\(candidate.kindTitle) \(candidate.displayName)")
        .accessibilityValue(isSelected ? "Will be removed" : "Kept")
        .accessibilityHint("Toggles whether this skill is removed")
    }
}
