import SwiftUI

/// The selected skills that cost the most context, largest first.
struct CleanupSavingsList: View {
    let candidates: [CleanupCandidate]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(candidates) { candidate in
                if candidate.id != candidates.first?.id {
                    Divider()
                        .opacity(0.45)
                }
                HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingM) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.displayName)
                            .lineLimit(1)
                        LastUsedText(date: candidate.lastUsed)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Metrics.spacingM)
                    Text("\(candidate.tokens, format: .number) tokens")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
