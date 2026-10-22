import SwiftUI

struct RunningRow: View {
    let process: RunningProcess
    let isStopping: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingS) {
            Circle()
                .fill(isStopping ? Color.orange : Color.green)
                .frame(width: 7, height: 7)
                .accessibilityLabel(isStopping ? "Stopping" : "Running")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.spacingXS) {
                    Text(process.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !process.ports.isEmpty {
                        Text(process.ports.map { ":\($0)" }.joined(separator: " "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let folder = process.folder {
            parts.append(folder.lastPathComponent)
        }
        if let startedBy = process.startedBy, startedBy != process.name {
            parts.append("from \(startedBy)")
        }
        parts.append(process.startedAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
        parts.append(process.memoryBytes.formatted(.byteCount(style: .memory)))
        return parts.joined(separator: " · ")
    }
}
