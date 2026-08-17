import AppKit
import SwiftUI

/// One folder in the onboarding list: name on the left, path on the right.
struct OnboardingScanLocationRow: View {
    let root: ScanRoot
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: root.isCustom ? "folder.badge.plus" : "folder.fill")
                .font(.system(size: 13))
                .foregroundStyle(root.exists ? OnboardingStyle.brandDeep : Color.secondary)
                .frame(width: 18)

            Text(root.title)
                .font(.callout)
                .lineLimit(1)

            Spacer(minLength: 16)

            Text(displayPath)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)

            trailingStatus
                .frame(width: 16)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(.rect)
        .opacity(root.exists ? 1 : 0.5)
        .contextMenu {
            if root.exists {
                Button("Reveal in Finder", systemImage: "folder", action: reveal)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if let onRemove {
            Button("Remove \(root.title)", systemImage: "xmark.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
        } else if root.exists {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Found")
        } else {
            Image(systemName: "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.quaternary)
                .accessibilityLabel("Not on this Mac")
        }
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
