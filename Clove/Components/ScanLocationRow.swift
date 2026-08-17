import AppKit
import SwiftUI

struct ScanLocationRow: View {
    let root: ScanRoot
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            IconTile(
                systemImage: root.isCustom ? "folder.badge.plus" : "folder",
                tint: root.exists ? .blue : .gray,
                size: 18
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(root.title)
                    .font(.callout)
                    .lineLimit(1)

                Text(displayPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Metrics.spacingS)

            if root.exists {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Found")
            } else {
                Text("Not found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let onRemove {
                Button("Remove \(root.title)", systemImage: "minus.circle", action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
        .contextMenu {
            if root.exists {
                Button("Reveal in Finder", systemImage: "folder", action: reveal)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var displayPath: String {
        root.path.replacingOccurrences(
            of: URL.homeDirectory.path(percentEncoded: false),
            with: "~/"
        )
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([root.url])
    }
}
